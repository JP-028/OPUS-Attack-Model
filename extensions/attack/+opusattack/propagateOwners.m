function OUT = propagateOwners(tspan, owners, N, launches, VAR)
% Propagate owner S/D/Su counts and shared debris using the original MOCAT laws.
% owners.ids: unique owner IDs. owners.S/D/Su: N_shell-by-N_owner counts.
% N: N_shell-by-1 shared debris counts.
% launches.S/Su: N_shell-by-N_owner constant rates [satellites/year].
% VAR.k_star must be set, as in the original IAM setup. Time is in years.
% Integrates attributed expected flow counts. No individual collision incidents.
    validateattributes(tspan, {'numeric'}, {'real','vector','finite','nonnegative'});
    if numel(tspan) < 2 || any(diff(tspan) <= 0)
        error('OPUS:InvalidTimeSpan', 'Supply at least two strictly increasing times in years.');
    end
    validatePhysics(VAR);
    n = VAR.N_shell;
    if ~isstruct(owners) || ~isfield(owners,'ids') || ...
            ~iscellstr(owners.ids) || isempty(owners.ids) || ~isvector(owners.ids) %#ok<ISCLSTR>
        error('OPUS:InvalidOwnerState', 'owners.ids must be a nonempty cell vector of owner IDs.');
    end
    ids = owners.ids(:)';
    if any(cellfun(@isempty, ids)) || numel(unique(lower(string(ids)))) ~= numel(ids)
        error('OPUS:InvalidOwnerState', 'Owner IDs must be nonempty and unique, ignoring case.');
    end
    m = numel(ids);
    for name = {'S','D','Su'}
        checkCounts(owners, name{1}, [n,m], 'OPUS:InvalidOwnerState');
    end
    if ~isnumeric(N) || ~isreal(N) || ~isequal(size(N),[n,1]) || ...
            any(~isfinite(N(:))) || any(N(:) < 0)
        error('OPUS:InvalidDebrisState', 'N must be a finite, nonnegative N_shell-by-1 vector.');
    end
    for name = {'S','Su'}
        checkCounts(launches, name{1}, [n,m], 'OPUS:InvalidOwnerLaunches');
    end

    % Only this setup calculation needs an upstream function on the MATLAB path.
    % Restore the path even if the density calculation fails.
    extensionRoot = fileparts(fileparts(mfilename('fullpath')));
    opusRoot = fileparts(fileparts(extensionRoot));
    previousPath = path;
    cleanup = onCleanup(@() path(previousPath)); %#ok<NASGU>
    addpath(fullfile(opusRoot,'MOCAT4S'));
    rho = arrayfun(@densityexp, VAR.R02(1:n));
    % Use a column regardless of upstream R0 orientation.
    radius = VAR.R0(1:n);
    speed = rho(:).*sqrt(VAR.mu*radius(:))*(24*3600*365.25);
    physics = VAR;
    physics.dragOutD = speed*VAR.beta(2)/VAR.Dhl;
    physics.dragInD = -speed*VAR.beta(2)/VAR.Dhu;
    physics.dragOutN = speed*VAR.beta(3)/VAR.Dhl;
    physics.dragInN = -speed*VAR.beta(3)/VAR.Dhu;
    path(previousPath);

    block = n*m;
    initial = [owners.S(:); owners.D(:); owners.Su(:); N(:)];
    model = buildFlowModel(launches,physics,n,m,ids);
    opts = odeset('RelTol',1e-8,'AbsTol',1e-8,'NonNegative',1:numel(initial));
    rhs = @(~,x) flowRhs(x,model);
    [T,Z] = ode45(rhs, tspan, [initial;zeros(height(model.definition),1)], opts);
    X = Z(:,1:model.stateSize);
    if T(end) < tspan(end) || any(~isfinite(Z(:))) || any(X(:) < 0)
        error('OPUS:PropagationFailed', 'Integration did not finish with finite, nonnegative populations.');
    end
    OUT.T = T;
    OUT.owners.ids = ids;
    OUT.owners.S = reshape(X(:,1:block),numel(T),n,m);
    OUT.owners.D = reshape(X(:,block+1:2*block),numel(T),n,m);
    OUT.owners.Su = reshape(X(:,2*block+1:3*block),numel(T),n,m);
    OUT.S = sum(OUT.owners.S,3);
    OUT.D = sum(OUT.owners.D,3);
    OUT.Su = sum(OUT.owners.Su,3);
    OUT.N = X(:,3*block+1:end);
    OUT.total = OUT.S + OUT.D + OUT.Su + OUT.N;
    OUT.launches = launches;
    OUT.parameters = VAR;
    OUT.flow_definition = model.definition;
    OUT.cumulative_flows = Z(:,model.stateSize+1:end);
    OUT.balance_residual = X - initial' - OUT.cumulative_flows*model.routing';
    OUT.max_balance_residual = max(abs(OUT.balance_residual(:)));
    OUT.final.owners.ids = ids;
    OUT.final.owners.S = reshape(X(end,1:block),n,m);
    OUT.final.owners.D = reshape(X(end,block+1:2*block),n,m);
    OUT.final.owners.Su = reshape(X(end,2*block+1:3*block),n,m);
    OUT.final.N = OUT.N(end,:)';
end


function checkCounts(value, field, dimensions, identifier)
    if ~isstruct(value) || ~isfield(value,field) || ...
            ~isnumeric(value.(field)) || ~isreal(value.(field)) || ...
            ~isequal(size(value.(field)),dimensions) || ...
            any(~isfinite(value.(field)(:))) || any(value.(field)(:) < 0)
        error(identifier, '%s must be a finite, nonnegative N_shell-by-N_owner matrix.', field);
    end
end

function validatePhysics(V)
    required = {'N_shell','k_star','Dt','P','delta','alpha','alpha_active', ...
        'slot_par','phi','K0','V','beta','mu','R0','R02','Dhl','Dhu'};
    if ~isstruct(V) || ~all(isfield(V,required))
        error('OPUS:InvalidOwnerPhysics', 'Supply complete MOCAT parameters including the disposal boundary k_star.');
    end
    validateattributes(V.N_shell,{'numeric'},{'scalar','integer','positive','finite'});
    validateattributes(V.k_star,{'numeric'},{'scalar','integer','>=',1,'<=',V.N_shell});
    validateattributes(V.Dt,{'numeric'},{'scalar','real','positive','finite'});
    for field = {'P','alpha','alpha_active','slot_par'}
        validateattributes(V.(field{1}),{'numeric'},{'scalar','real','finite','>=',0,'<=',1});
    end
    validateattributes(V.delta,{'numeric'},{'scalar','real','finite','nonnegative'});
    validateattributes(V.phi,{'numeric'},{'size',[4,4],'real','finite','nonnegative'});
    validateattributes(V.K0,{'numeric'},{'size',[4,4],'real','finite','nonnegative'});
    validateattributes(V.V,{'numeric'},{'vector','numel',V.N_shell,'real','finite','positive'});
    validateattributes(V.beta,{'numeric'},{'vector','numel',4,'real','finite','nonnegative'});
    validateattributes(V.mu,{'numeric'},{'scalar','real','finite','positive'});
    validateattributes(V.Dhl,{'numeric'},{'scalar','real','finite','positive'});
    validateattributes(V.Dhu,{'numeric'},{'scalar','real','finite','<',0});
    validateattributes(V.R0,{'numeric'},{'vector','real','finite','positive'});
    validateattributes(V.R02,{'numeric'},{'vector','real','finite','nonnegative'});
    if numel(V.R0) < V.N_shell || numel(V.R02) < V.N_shell
        error('OPUS:InvalidOwnerPhysics', 'Orbital radius and altitude arrays must cover all shells.');
    end
end
