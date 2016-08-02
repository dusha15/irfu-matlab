% Author: Erik P G Johansson, IRF-U, Uppsala, Sweden
% First created 2016-07-28
%
% This function decides the path and filename of the master CDF file to use.
% (The S/W descriptor needs the filename only. The execution of a S/W mode needs the entire path.)
%
function [master_CDF_path, master_filename] = get_master_CDF_path(dataset_ID, dataset_version_str)
% QUESTION: Should define the master CDFs name (constuct it with code), or look it up among the constants?
% PROPOSAL: Move function into constants.
% PROPOSAL: Retrieve value from constants somehow (or rather, verify with constants).
%
    global CONSTANTS
    
    master_filename = [dataset_ID, '_V', dataset_version_str, '.cdf'];
    master_CDF_path = [CONSTANTS.SW_root_dir(), filesep, CONSTANTS.C.master_CDFs_dir_rel, filesep, master_filename];
end

