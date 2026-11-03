function OUT = propagateScenario(parameter_file, tspan, launches)
% Physical-only run of an enabled owner scenario; no attack events/controllers.
% Omitted launches means explicit zero launches. Supplied S/Su matrices are
% constant rates [satellites/year], with columns in scenario.attack.owners.ids order.
    scenario = opusattack.prepareScenario(parameter_file);
    if ~scenario.attack.enabled
        error('OPUS:AttackNotEnabled', 'Owner propagation requires an enabled extension scenario.');
    end
    if ~isempty(scenario.attack.events)
        error('OPUS:EventsRequireScenarioRunner','Use opusattack.runScenario to execute configured attack events.');
    end
    owners = scenario.attack.owners;
    VAR = scenario.VAR;
    if nargin < 3
        launches = struct('S',zeros(size(owners.S)), 'Su',zeros(size(owners.Su)));
    end
    [VAR,costs] = prepareDynamics(scenario);
    N = VAR.x0(2*VAR.N_shell+1:3*VAR.N_shell);
    OUT = opusattack.propagateOwners(tspan,owners,N,launches,VAR);
    OUT.scenario = scenario;
    OUT.cost_parameters = costs;
end
