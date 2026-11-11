function [VAR, econ_params, constellation_params, attack_params] = modifyParameters(VAR, econ_params, constellation_params, parameter_file)
    % Extension-only parameter adapter. Does not replace upstream modifyParameters.
    % Numeric MOCAT/econ overrides retain the original OPUS assignment behavior;
    % attack settings are understood only by this namespaced adapter.
    %
    % Inputs:
    %   VAR - Struct containing physical parameters
    %   econ_params - Struct containing economic parameters
    %   constellation_params - Struct containing constellation parameters
    %   parameter_file - CSV file containing parameter modifications
    %
    % Outputs:
    %   VAR - Modified physical parameters
    %   econ_params - Modified economic parameters
    %   constellation_params - Modified constellation parameters
    %
    % NOTES: Code currently assumes that the parameter_value column contains numerical values. If any of the parameters are meant to be strings or other non-numeric types, additional handling will be required.

    % Attack scenarios are opt-in and configured independently for each run.
    attack_params = struct('enabled', false);

    % Check if parameter_file is not "benchmark"
    if ~strcmp(parameter_file, 'benchmark')
        % Read the CSV file
        parameters = readtable(parameter_file);

        % Loop through each row of the parameters table
        for i = 1:height(parameters)
            parameter_type = parameters.parameter_type{i};
            parameter_name = parameters.parameter_name{i};
            parameter_value = parameters.parameter_value(i);

            % Modify the value based on parameter_type
            switch parameter_type
                case 'MOCAT'
                    % If the field exists in VAR, update its value
                    if isfield(VAR, parameter_name)
                        VAR.(parameter_name) = parameter_value;
                    end
                case 'econ'
                    % If the field exists in econ_params, update its value
                    if isfield(econ_params, parameter_name)
                        econ_params.(parameter_name) = parameter_value;
                    end
                case 'attack'
                    if ~ismember(parameter_name, {'enabled','additional_constellations'}) || ~isscalar(parameter_value) || ...
                            ~isnumeric(parameter_value) || ~isfinite(parameter_value) || ...
                            ~ismember(parameter_value, [0, 1])
                        error('OPUS:InvalidAttackConfiguration', ...
                            'Attack settings enabled and additional_constellations require numeric 0 or 1.');
                    end
                    % Do not add default fields: existing scenario identities stay stable.
                    if strcmp(parameter_name,'enabled') || parameter_value==1
                        attack_params.(parameter_name) = logical(parameter_value);
                    elseif isfield(attack_params,parameter_name)
                        attack_params=rmfield(attack_params,parameter_name);
                    end
                otherwise
                    warning('Unknown parameter_type: %s', parameter_type);
            end
        end
    end
end
