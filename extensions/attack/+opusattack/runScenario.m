function runScenario(parameter_file)
% Separate attack entry point. Dynamics will be added here in a later step.
    scenario = opusattack.prepareScenario(parameter_file);
    if ~scenario.attack.enabled
        error('OPUS:AttackNotEnabled', ...
            'This entry point requires attack,enabled,1. Use the original OPUS workflow for ordinary runs.');
    end
    error('OPUS:AttackModelNotImplemented', ...
        'Owner inputs validated. Owner propagation and attack events are not implemented yet.');
end
