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


%% HBCD input
%add path to pconns
inpath='/mypath/hbcd_data_grab/xcp_d/';
%read in list of subjects and sessions
T = readtable([ inpath 'zero_to_four.tsv'], 'FileType', 'text');
%generate list of filenames for runs 1 and 2 of these subjects/sessions -
%note, they might not all exist
for i=1:size(T,1)
    sub=(cell2mat(T.Var1(i)));
    pconns1(i,:)=['xcp_d/' sub '/ses-V02/func/' sub '_ses-V02_task-rest_dir-PA_run-1_space-fsLR_seg-Gordon_den-91k_stat-pearsoncorrelation_boldmap.pconn.nii'];
    pconns2(i,:)=['xcp_d/' sub '/ses-V02/func/' sub '_ses-V02_task-rest_dir-PA_run-2_space-fsLR_seg-Gordon_den-91k_stat-pearsoncorrelation_boldmap.pconn.nii'];

end

%load pconn data of runs 1 and 2. 
for k=1:size(pconns1,1)
    try
        %first: try if run 1 exists
    subdata=cifti_read([inpath pconns1(k,:)]);
        try
            %second: try if run 2 exists as well and average across runs 1
            %and 2
        subdata2=cifti_read([inpath pconns2(k,:)]);
        subdata.cdata=(subdata.cdata+subdata2.cdata)/2;
        catch
        end
    catch
        %if run 1 did not exist but run 2 does, use this run 
    subdata=cifti_read([inpath pconns2(k,:)]);
    end
    %write data from every sub/ses pair into a 3D matrix (333 x 333 Gordon
    %parcels plus k subjects)
    all_sub(:,:,k)=subdata.cdata;
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
cifti_write(extra_pconn, 'avg_HBCD_1mo.pconn.nii')
% save whole matrix for faster loading
save('HBCD_all_avged_pconns.mat', 'all_sub')

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
writetable(output_table, "HBCD_summary_within_between.csv");