function [ amp_dist_all,order_dist,order,MI_surr, MI_raw, MI_norm, ...
         comodulogram_column_headers, comodulogram_row_headers, comodulogram_third_dim_headers]...
         = generate_MI_surr(flist,outcomes,src_dir,save_dir,groups)
% Generates MI surrogate, save surrogate as PAC_analysis_variables.mat
% Saves each beapp output file in a results file type that is compatible
% with rest of pipeline


%OUTPUTS
%amp_dist_all : all subjects amp_dist (amplitude distance across the 18 phase bins)
%order : order of beapp filenames (_pac_results.mat)
%order_dist : identical to order, replace in future revision to save redundancy
% MI_raw block -- "rawmi_comod"
% MI_surr block-- surr_comod generated by calculate surrogate 
% MI_norm -- zscore_comod
%comodulogram_column_headers -- hf lables %check this isn't swapped
%comodulogram_row_headers -- lf labels %check this isn't swapped
%comodulogram_third_dim_headers -- chan_labels

% for each channel

% initialize counts for the order
dx_count = [0 0]; 
n_bins= 18;
total_count = 0;
%load one to initialize
for f = 1:size(flist,1)
    
    disp(f);
    disp(flist{f});
    cd(src_dir);

    % load file
    load(flist{f});
    chan_idxs = file_proc_info.net_10_20_elecs;
    %check for missing channels/pad with nans
    curr_good_chans = cell2mat(cellfun(@(x) (str2num(x(10:end))),comodulogram_third_dim_headers,'UniformOutput',false));
    missing_chans = setdiff(chan_idxs,curr_good_chans);
    if ~isempty(missing_chans)
        missing_chans = sort(missing_chans);
        for missing_chan = 1:length(missing_chans)
            %rawmi
            chan_to_insert = find(chan_idxs == missing_chans(missing_chan));
            temp_raw{1,1}(:,:,1:chan_to_insert-1) = rawmi_comod{1,1}(:,:,1:chan_to_insert-1);
            temp_raw{1,1}(:,:,chan_to_insert) = nan(size(rawmi_comod{1,1},1),size(rawmi_comod{1,1},2),1);
            temp_raw{1,1}(:,:,chan_to_insert+1:chan_to_insert+1+(size(rawmi_comod{1,1},3)-chan_to_insert)) = rawmi_comod{1,1}(:,:,chan_to_insert:end);
            rawmi_comod = temp_raw;
            %zscore comod
            temp_zscore{1,1}(:,:,1:chan_to_insert-1) = zscore_comod{1,1}(:,:,1:chan_to_insert-1);
            temp_zscore{1,1}(:,:,chan_to_insert) = nan(size(zscore_comod{1,1},1),size(zscore_comod{1,1},2),1);
            temp_zscore{1,1}(:,:,chan_to_insert+1:chan_to_insert+1+(size(zscore_comod{1,1},3)-chan_to_insert)) = zscore_comod{1,1}(:,:,chan_to_insert:end);
            zscore_comod = temp_zscore;
            %phase bias comod
            temp_phasebias{1,1}(:,:,1:chan_to_insert-1,:) = phase_bias_comod{1,1}(:,:,1:chan_to_insert-1,:);
            temp_phasebias{1,1}(:,:,chan_to_insert,:) = nan(size(phase_bias_comod{1,1},1),size(phase_bias_comod{1,1},2),1,size(phase_bias_comod{1,1},4));
            temp_phasebias{1,1}(:,:,chan_to_insert+1:chan_to_insert+1+(size(phase_bias_comod{1,1},3)-chan_to_insert),:) = phase_bias_comod{1,1}(:,:,chan_to_insert:end,:);
            phase_bias_comod = temp_phasebias;
            %amp dist
            temp_amp_dist{1,1}(:,:,:,1:chan_to_insert-1,:) = amp_dist{1,1}(:,:,:,1:chan_to_insert-1,:);
            temp_amp_dist{1,1}(:,:,:,chan_to_insert,:) = nan(size(amp_dist{1,1},1),size(amp_dist{1,1},2),size(amp_dist{1,1},3),1,size(amp_dist{1,1},5));
            temp_amp_dist{1,1}(:,:,:,chan_to_insert+1:chan_to_insert+1+(size(amp_dist{1,1},4)-chan_to_insert),:) = amp_dist{1,1}(:,:,:,chan_to_insert:end,:);
            amp_dist = temp_amp_dist;
            %comodulogram third dim headers
            comodulogram_third_dim_headers = [comodulogram_third_dim_headers(1:chan_to_insert-1),{strcat('Channel #',num2str(missing_chans))},comodulogram_third_dim_headers(chan_to_insert:end)];
        end
    end
    % don't count if nan (participant had fewer than 6 segments)
    if isnan(rawmi_comod{1,1}(1,1,1))
        disp('PAC not processed');
        continue;
    end
    total_count = total_count+1;


    surr_comod = calculate_surrogate(amp_dist,n_bins);

    % identify diagnosis
    id = flist{f};
    [dx,index] = check_dx(flist{f},outcomes,1); % dx should be 1 or 2 1 RTT 2 TD
    outcomes.ComputedSurr(index) = 1;
    if dx == 1 || dx == 2
        dx_count(1,dx)=dx_count(1,dx)+1;
        % save surrogate values
        MI_surr.(groups{dx})(:,:,:,dx_count(1,dx)) = surr_comod;
        % ASD_MIsurr(:,:,:,ASD_count) = surr_comod;

        % save raw MI
        MI_raw.(groups{dx})(:,:,:,dx_count(1,dx)) = rawmi_comod{:,:,:};
        %ASD_MIraw(:,:,:,ASD_count) = rawmi_comod{:,:,:};

        % save normed MI
        MI_norm.(groups{dx})(:,:,:,dx_count(1,dx)) = zscore_comod{:,:,:};
        %ASD_MInorm(:,:,:,ASD_count) = zscore_comod{:,:,:};

        % save order
        order.(groups{dx}){dx_count(1,dx)} = flist{f};
        %ASD_order{ASD_count} = flist{f};

        % save raw amp dist
        amp_dist_all.(groups{dx})(:,:,:,:,dx_count(1,dx)) = squeeze(amp_dist{1,1}(:,:,:,:,1));
       % amp_dist_all.(groups{dx})(:,:,:,:,dx_count(1,dx)) = squeeze(amp_dist(:,:,:,:,1));

        %ASD_amp_dist(:,:,:,:,ASD_count)=squeeze(amp_dist{1,1}(:,:,:,:,1));

        % save amp dist order
        order_dist.(groups{dx}){dx_count(1,dx)} = flist{f};
        %ASD_order_dist{dx_count(1,dx)} = id(1:9);
    else
        disp('NO DIAGNOSIS????')
    end

    cd(save_dir);
    save(strcat(strrep(id,'_pac_results.mat',''),'_pac_results','.mat'),'comodulogram',...
        'comodulogram_column_headers','comodulogram_row_headers',...
        'comodulogram_third_dim_headers','amp_dist','zscore_comod',...
        'rawmi_comod','phase_bias_comod','file_proc_info','surr_comod');

    clearvars -except groups chan_idxs amp_dist amp_dist_all order_dist total_count flist MIsurr n_bins ...
        MI_surr MI_raw MI_norm order dx_count src_dir save_dir outcomes comodulogram_column_headers comodulogram_row_headers comodulogram_third_dim_headers

end
 
cd([save_dir filesep 'PAC analysis variables']);
% save('TD_MIsurr.mat','TD_MIsurr');
% save('ASD_MIsurr.mat','ASD_MIsurr');
 save('PAC_analysis_variables.mat','MI_surr',...
     'MI_raw','MI_norm','order','order_dist','amp_dist_all','comodulogram_column_headers','comodulogram_row_headers','comodulogram_third_dim_headers'); %yb uncommented
% 
% % save outcome table
% writetable(outcomes,'PAC_log_t2.xlsx');