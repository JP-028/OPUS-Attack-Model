function [VAR,costs] = prepareDynamics(scenario)
    VAR=scenario.VAR;
    econ=scenario.econ_params;
    for field={'satLifetime','disposalTime'}
        validateattributes(econ.(field{1}),{'numeric'},{'scalar','real','finite','positive'});
    end
    for field={'discountRate','intercept','coef','tax','delta_v_cost','lift_price'}
        validateattributes(econ.(field{1}),{'numeric'},{'scalar','real','finite','nonnegative'});
    end
    extensionRoot=fileparts(fileparts(fileparts(mfilename('fullpath'))));
    opusRoot=fileparts(fileparts(extensionRoot));
    oldPath=path; cleanup=onCleanup(@() path(oldPath)); %#ok<NASGU>
    addpath(opusRoot,fullfile(opusRoot,'MOCAT4S'));
    % Fail before upstream buildCostFunction tries indexing an empty k_star.
    rho=arrayfun(@densityexp,VAR.R02(1:VAR.N_shell));
    r=VAR.R0(1:VAR.N_shell);
    rates=rho(:)*VAR.beta(2).*sqrt(VAR.mu*r(:))*(24*3600*365.25)/VAR.Dhl;
    if ~any(cumsum(1./rates)<=scenario.econ_params.disposalTime)
        error('OPUS:InvalidOwnerPhysics','Disposal time does not define a valid disposal shell.');
    end
    costs=buildCostFunction(VAR,scenario.econ_params);
    if any(~isfinite(costs.cost)) || any(costs.cost<=0)
        error('OPUS:InvalidOwnerEconomics','Original shell deployment costs must be finite and positive.');
    end
    VAR.k_star=costs.k_star;
end
