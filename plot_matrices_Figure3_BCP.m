clear all
close all
%load paths to toolboxes for loading and plotting data
addpath(genpath('/mypath/utilities/cifti-matlab'));
addpath(genpath('/mypath/utilities/gifti/'));
%repo location for showM tool: https://gitlab.com/ascario/plotting-tools
addpath(genpath('/mypath/utilities/plotting-tools/showM/'))
%load template for Gordon parcellation structure
parcel_struct=load('/mypath/parcel_schemas/Gordon.mat');
parcel=parcel_struct.parcel;


%% BCP input
%add path to pconns
inpath='/mypath/bcp_pconns/';
%read in list of subjects and sessions
T = readtable([ inpath 'bcp_pconns_participants.csv'], 'FileType', 'text');

%try to read in files for runs 1 and 2. try catch logic is used as file
%naming varies as well as acquisition directions
%loop over all i subjects
for i=1:size(T,1)
    sub=(cell2mat(T.participant_id(i)));
    ses=(cell2mat(T.session_id(i)));
    try
        %see if run-01 in AP direction extsts
        pconns1=['final_set/' sub '_' ses '_task-rest_dir-AP_run-01_space-fsLR_seg-Gordon_den-91k_stat-mean_timeseries.ptseries.nii_all_frames_at_FD_none.pconn.nii'];
        subdata=cifti_read([inpath pconns1]);
    catch
        try
            %see if run-01 in PA direction exists
            pconns1=['final_set/' sub '_' ses '_task-rest_dir-PA_run-01_space-fsLR_seg-Gordon_den-91k_stat-mean_timeseries.ptseries.nii_all_frames_at_FD_none.pconn.nii'];
            subdata=cifti_read([inpath pconns1]);
        catch
           try
               %check for alternative file naming
                pconns1=['final_set/' sub '_' ses '_task-rest_dir-AP_run-001_space-fsLR_seg-Gordon_den-91k_stat-mean_timeseries.ptseries.nii_all_frames_at_FD_none.pconn.nii'];
                subdata=cifti_read([inpath pconns1]);
           catch
                try
                pconns1=['final_set/' sub '_' ses '_task-rest_dir-PA_run-001_space-fsLR_seg-Gordon_den-91k_stat-mean_timeseries.ptseries.nii_all_frames_at_FD_none.pconn.nii'];
                subdata=cifti_read([inpath pconns1]);
                catch
                    %if there is no run 1, create placeholder
                    subdata=[];
                end
           end
        end
    end

    try
        %same logic for run-02. If runs 1 and 2 exist, average over them
        pconns2=['final_set/' sub '_' ses '_task-rest_dir-AP_run-02_space-fsLR_seg-Gordon_den-91k_stat-mean_timeseries.ptseries.nii_all_frames_at_FD_none.pconn.nii'];
        subdata2=cifti_read([inpath pconns2]);
        subdata.cdata=(subdata.cdata+subdata2.cdata)/2;
    catch
        try
            pconns2=['final_set/' sub '_' ses '_task-rest_dir-PA_run-02_space-fsLR_seg-Gordon_den-91k_stat-mean_timeseries.ptseries.nii_all_frames_at_FD_none.pconn.nii'];
            subdata2=cifti_read([inpath pconns2]);
            subdata.cdata=(subdata.cdata+subdata2.cdata)/2;
        catch
           try
                pconns2=['final_set/' sub '_' ses '_task-rest_dir-AP_run-002_space-fsLR_seg-Gordon_den-91k_stat-mean_timeseries.ptseries.nii_all_frames_at_FD_none.pconn.nii'];
                subdata2=cifti_read([inpath pconns2]);
                subdata.cdata=(subdata.cdata+subdata2.cdata)/2; 
           catch
               try
                pconns2=['final_set/' sub '_' ses '_task-rest_dir-PA_run-002_space-fsLR_seg-Gordon_den-91k_stat-mean_timeseries.ptseries.nii_all_frames_at_FD_none.pconn.nii'];
                subdata2=cifti_read([inpath pconns2]);
                subdata.cdata=(subdata.cdata+subdata2.cdata)/2;
               catch
                   try
                       %if the above don't work, as there is only a run 2
                       %but no run 1, use this as main 'subdata'
                   subdata=cifti_read([inpath pconns2]);
                   catch
                       %otherwise ignore run 2
                   end
               end
           end
        end
    end
    if isempty(subdata)
        %if there is no run 1 or 2, check, if there for some reason is a
        %run 3 instead and pivot to using this one
        try
            subdata=subdata2;
        catch
        pconns3=['final_set/' sub '_' ses '_task-rest_dir-AP_run-03_space-fsLR_seg-Gordon_den-91k_stat-mean_timeseries.ptseries.nii_all_frames_at_FD_none.pconn.nii'];
        subdata=cifti_read([inpath pconns3]);
        end
    else
    end
    %summarize data from all subejcts into matrix (33x33 Gordon parcels
    %with i subjects as 3rd dimension)
    all_sub(:,:,i)=subdata.cdata;
 end


%%
%for plot: average across all subjects
subavg=squeeze(nanmean(all_sub, 3));
%matrix plot sorted by assignment of Gordon parcels to networks
showM(subavg,...
 'parcel',parcel,...
 'one_side_labels', 1, ....
 'line_color',[0 0 0],...
 'line_width',0.3,...
 'clims',[-.5 .5],...
 'fs_axis',10,...
 'fig_wide',14,...
 'fig_tall',15);

%% write out avg pconn
%create variable with pconn structure
extra_pconn=subdata;
%place average data in structure
extra_pconn.cdata=subavg;
%safe data - can be used for visualizations on a surface
cifti_write(extra_pconn, 'avg_BCP.pconn.nii')
% save whole matrix for faster loading
save('BCP_avged_pconns.mat', 'all_sub')

%% calcualte within and between network connectivity
for k=1:size(parcel,2)
    %loop over all k networks (captured in the 'parcel' variable - variable naming comes from auditory
    %networkbeing the first one

    %within: select square that captures within network connections -
    %parcel.ix contains all parcel lables that are asigned to one network
    aud_within=all_sub(parcel(k).ix, parcel(k).ix,:);

    %between: first select all connections of parcels of a given network
    %with all other parcels
    aud_between=all_sub(parcel(k).ix, :,:);
    %second: exclude connections within the same network (as they are
    %captured as 'within')
    aud_between(:, parcel(k).ix,:)=[];
    %loop across all participants for one network
    for i=1:size(all_sub,3)
        % select matrix for a single subject (within)
        singlesub_aud_within=aud_within(:,:,i);
         % create vector from matrix. choose: upper triangle, excluding the
        % diagonal (as it is the connectivity of a parcel with itself).
        % Make sure to not include naN's, if they occur
        aud_within_vec=singlesub_aud_within(logical(triu(~isnan(singlesub_aud_within),1)));
        % average across vector for mean within network connectivity
        aud_within_mean(i,1)=mean(aud_within_vec);

        %select matrix for a single subject (between)
        singlesub_aud_between=aud_between(:,:,i);
        %reshape to a vector - as these are between parcel connections,
        %there are no douplicates or connections with itself like in the
        %within parcel connections
        aud_between_vec=reshape(singlesub_aud_between, [], 1);
        %average across vextor for mean between network connectivity
        aud_between_mean(i,1)=nanmean(aud_between_vec);
       
    end
    % average across all mean connections across subjects for each network
    mean_aud_within_mean(k,1)=mean(aud_within_mean);
    % calculate the standard deviation across subjects
    sd_aud_within_mean(k,1)=std(aud_within_mean);
    
    mean_aud_between_mean(k,1)=mean(aud_between_mean);
    sd_aud_between_mean(k,1)=std(aud_between_mean);

end
%%
%set up table to capture outputs
%1. network names
network=[vertcat(parcel.shortname); vertcat(parcel.shortname)];
%2. labels for within and between condition
condition=[repelem("Within", size(parcel,2)), repelem("Between", size(parcel,2))]';
%3. concatenate mean values
mean_value=[mean_aud_within_mean; mean_aud_between_mean];
%4. concatenate SD values
sd_value=[sd_aud_within_mean; sd_aud_between_mean];

%summarize and save
output_table=table(network, condition, mean_value, sd_value);
writetable(output_table, "BCP_summary_within_between.csv");
