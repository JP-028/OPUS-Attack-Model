function scenario = prepareScenario(parameter_file, model_type)
% Read extension configuration and owner inputs without running or writing files.
% Uses upstream OPUS initializers; does not modify or shadow upstream functions.
    if nargin < 1
        parameter_file = 'benchmark';
    end
    if nargin < 2
        model_type = 'MOCAT';
    end
    if ~strcmp(model_type, 'MOCAT')
        error('OPUS:UnsupportedAttackModel', 'This extension currently supports MOCAT only.');
    end
    % Resolve input relative to the caller before entering the upstream root.
    if ~strcmp(parameter_file, 'benchmark')
        [exists, info] = fileattrib(parameter_file);
        if ~exists || info.directory
            error('OPUS:MissingScenarioFile', 'Scenario file not found: %s', parameter_file);
        end
        parameter_file = info.Name;
    end
    extensionRoot = fileparts(fileparts(mfilename('fullpath')));
    opusRoot = fileparts(fileparts(extensionRoot));
    originalFolder = pwd;
    originalPath = path;
    cleanup = onCleanup(@() restoreEnvironment(originalFolder, originalPath)); %#ok<NASGU>
    % Upstream initializers use paths relative to their repository root.
    cd(opusRoot);
    addpath(opusRoot, fullfile(opusRoot,'MOCAT4S'), fullfile(opusRoot,'GMPHD'));
    VAR = MOCAT4S_VAR_Cons();
    GMPHD_params = GMPHD_VAR_Cons();
    econ_params = set_econ_parameters(VAR);
    constellation_params = constellation_parameters('scenarios/parsets/constellation-parameters.csv');
    [VAR, econ_params, constellation_params, attack_params] = ...
        opusattack.modifyParameters(VAR, econ_params, constellation_params, parameter_file);
    if attack_params.enabled
        attack_params.owners = opusattack.loadOwners(parameter_file, VAR);
    end
    % Preserve the upstream naming inputs for disabled scenarios. Owner counts
    % participate in enabled scenario identities, without writing output folders.
    launch_mask = ones(1,40);
    encoded = [jsonencode(VAR), jsonencode(GMPHD_params), jsonencode(econ_params), ...
        jsonencode(constellation_params), jsonencode(launch_mask)];
    if attack_params.enabled
        encoded = [encoded, jsonencode(attack_params)];
    end
    digest = java.security.MessageDigest.getInstance('SHA-256');
    hash = digest.digest(uint8(encoded));
    scenario.name = generateUniqueName(sprintf('%02x', hash));
    scenario.model_type = model_type;
    scenario.VAR = VAR;
    scenario.econ_params = econ_params;
    scenario.constellation_params = constellation_params;
    scenario.attack = attack_params;
end

function restoreEnvironment(folder, searchPath)
    cd(folder);
    path(searchPath);
end
