function s2f_save_sc_matrix_matlab(path_dwi, path_out, subject, seed, stat, measure, atlas, overwrite)
% Convert all the scv files to mat files

outfile = sprintf('%s/%s_%s_seed_dynamic_sift2_%s_sc.mat',path_out,subject,seed ,atlas);

% Check if the matrix is already calculated
if exist(outfile)

MRtrix = load(outfile);

if strcmp(measure,"num_streamlines")
	current_matrix_raw = sprintf('%s_raw',measure);
else 
	current_matrix_raw = sprintf('%s_%s_raw',stat,measure);
end

if isfield(MRtrix,current_matrix_raw)  
	switch overwrite
		case 0

			fprintf(1,'  Already saved. Skipping...\n' );
			return

		case 1
			MRtrix = rmfield(MRtrix,current_matrix_raw);
	end

end


end

if strcmp(measure,"num_streamlines")

current = dir(sprintf('%s/%s/structural_measures/%s_%s_seed_dynamic_sift2_%s_%s.csv',...
                path_dwi,subject,subject,seed,atlas,measure));


% Check if there is any structural connectivity matrix to transform
if isempty(current)
	fprintf(1,'  Measure %s. File not found. Skipping...\n', measure );
	return
end


% Select the current subject
current = sprintf("%s/%s",current.folder, current.name);
[~,file_name,~] = fileparts(current);
            
% Get the matrix
matrix_raw = readmatrix(current);
            
% Apply the mu coefficient obtained from tcksift2
fid = fopen(sprintf('%s/%s/structural_measures/%s_%s_mu_coefficient.txt',...
	path_dwi,subject,subject,seed));
mu = fscanf(fid,'%f');
fclose(fid);
matrix_raw = (mu+1) * matrix_raw;
            
%Make the matrix symmetric
matrix_raw = matrix_raw + triu(matrix_raw,1)';            
       
% Save the results
current_matrix_raw = sprintf('%s_raw', measure);
            
MRtrix.(current_matrix_raw) = matrix_raw;
MRtrix.mu   = mu;
MRtrix.mu_coefficient = "Already applied. Regularization parametrer from MRtrix";

% If exists, append the results
save(outfile,'-struct','MRtrix');



else

current = dir(sprintf('%s/%s/structural_measures/%s_%s_seed_dynamic_sift2_%s_%s_%s.csv',...
                path_dwi,subject,subject,seed,atlas,stat,measure));


% Check if there is any structural connectivity matrix to transform
if isempty(current)
	fprintf(1,'  Measure %s. File not found. Skipping...\n', measure );
	return
end


% Select the current subject
current = sprintf("%s/%s",current.folder, current.name);
[~,file_name,~] = fileparts(current);
            
% Get the matrix
matrix_raw = readmatrix(current);
            
% Apply the mu coefficient obtained from tcksift2
fid = fopen(sprintf('%s/%s/structural_measures/%s_%s_mu_coefficient.txt',...
	path_dwi,subject,subject,seed));
mu = fscanf(fid,'%f');
fclose(fid);
matrix_raw = (mu+1) * matrix_raw;
            
%Make the matrix symmetric
matrix_raw = matrix_raw + triu(matrix_raw,1)';            
       
% Save the results
current_matrix_raw = sprintf('%s_%s_raw',stat, measure);
            
MRtrix.(current_matrix_raw) = matrix_raw;
MRtrix.mu   = mu;
MRtrix.mu_coefficient = "Already applied. Regularization parametrer from MRtrix";

% If exists, append the results
save(outfile,'-struct','MRtrix');

end


end
