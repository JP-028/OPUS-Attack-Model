function [excess,revenue,probability,cost] = economicReturn(state,pop,k,V,econ,costs,multiplier)
% OPUS linear fringe revenue and cost/discount/lifetime/risk return form.
% The collision probability here is a per-satellite hazard from the same
% MOCAT loss terms used by propagateOwners. Original OPUS's MATLAB helper
% returns a shell-wide Su collision count proxy, and has an empty-shell 0/0.
    validateattributes(econ.intercept,{'numeric'},{'scalar','real','finite','nonnegative'});
    validateattributes(econ.coef,{'numeric'},{'scalar','real','finite','nonnegative'});
    validateattributes(econ.discountRate,{'numeric'},{'scalar','real','finite','nonnegative'});
    validateattributes(econ.tax,{'numeric'},{'scalar','real','finite','nonnegative'});
    validateattributes(econ.satLifetime,{'numeric'},{'scalar','real','finite','positive'});
    revenue=econ.intercept-econ.coef*sum(state.Su(end,:));
    cost=costs.cost(k)*multiplier;
    if ~isfinite(cost) || cost<=0
        error('OPUS:InvalidOwnerEconomics','Owner deployment cost must be finite and positive.');
    end
    S=state.S(end,k); Su=state.Su(end,k);
    D=state.D(end,k); N=state.N(end,k);
    p=V.phi/V.V(k);
    cross=0;
    if S+Su>0, cross=S*Su/(S+Su); end
    switch string(pop)
        case "S"
            hazard=(V.delta+V.alpha)*(p(1,3)*N+p(1,2)*D) + ...
                V.alpha_active*((1-V.slot_par)*p(1,1)*S+p(1,4)*cross);
        case "Su"
            hazard=(V.delta+V.alpha)*(p(3,4)*N+p(2,4)*D) + ...
                V.alpha_active*(p(4,4)*Su+p(1,4)*cross);
        otherwise
            error('OPUS:InvalidOwnerEconomics','Economic returns require S or Su.');
    end
    if ~isfinite(hazard) || hazard<0
        error('OPUS:InvalidOwnerEconomics','Collision hazard must be finite and nonnegative.');
    end
    probability=-expm1(-hazard);
    excess=100*(revenue/cost-econ.discountRate-1/econ.satLifetime- ...
        probability*(1+econ.tax));
end
