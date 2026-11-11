function [owners, initialState] = loadOwners(parameter_file, VAR, x0, populationMode)
% Load one CSV per owner from <parameter-file-stem>-owners beside the parset.
% Each CSV has shell,S,Su,D columns and exactly one row for every shell.
% The filename (without .csv) is the owner ID. No ownership is inferred.
% Default 'allocation' requires sums to match the MOCAT state. 'additional'
% adds owner CSV populations to the input S/Su/D, assigned to automatic generic.
% Shared N is retained once. The additional mode reserves the ID 'generic'.
    n = VAR.N_shell;
    if nargin < 3
        x0 = VAR.x0;
    end
    if nargin < 4, populationMode = 'allocation'; end
    if ~isscalar(string(populationMode)) || ~ismember(string(populationMode), ["allocation","additional"])
        error('OPUS:InvalidOwnerPopulationMode','Use allocation or additional owner population mode.');
    end
    if ~isnumeric(x0) || ~isvector(x0) || numel(x0) ~= 4*n || ...
            any(~isfinite(x0(:))) || any(x0(:) < 0)
        error('OPUS:InvalidOwnerBaseline', 'Expected a finite, nonnegative four-population MOCAT state.');
    end
    [parent, stem] = fileparts(parameter_file);
    folder = fullfile(parent, [stem '-owners']);
    files = dir(fullfile(folder, '*.csv'));
    files = files(~[files.isdir]);
    if isempty(files) && ~(string(populationMode)=="additional" && isfolder(folder))
        error('OPUS:MissingOwnerFiles', 'Add one owner CSV per owner in %s.', folder);
    end
    [~, order] = sort({files.name});
    files = files(order);
    owners.ids = cell(1, numel(files));
    owners.S = zeros(n, numel(files));
    owners.Su = zeros(n, numel(files));
    owners.D = zeros(n, numel(files));
    for i = 1:numel(files)
        [~, id] = fileparts(files(i).name);
        if isempty(regexp(id, '^[A-Za-z0-9][A-Za-z0-9_-]*$', 'once'))
            error('OPUS:InvalidOwnerId', 'Owner filename %s must use letters, digits, underscores or hyphens.', files(i).name);
        end
        if any(strcmpi(owners.ids(1:i-1), id))
            error('OPUS:DuplicateOwnerId', 'Owner ID %s occurs more than once.', id);
        end
        owners.ids{i} = id;
        filename = fullfile(folder, files(i).name);
        data = readtable(filename, 'VariableNamingRule', 'preserve');
        if ~isequal(sort(data.Properties.VariableNames), sort({'shell', 'S', 'Su', 'D'}))
            error('OPUS:InvalidOwnerColumns', '%s must contain exactly the columns shell,S,Su,D.', filename);
        end
        if ~isnumeric(data.shell) || height(data) ~= n || ...
                ~isequal(sort(data.shell), (1:n)')
            error('OPUS:InvalidOwnerShells', '%s must list each shell from 1 to %d exactly once.', filename, n);
        end
        if ~isnumeric(data.S) || ~isnumeric(data.Su) || ~isnumeric(data.D) || ...
                any(~isfinite(data.S)) || any(~isfinite(data.Su)) || any(~isfinite(data.D)) || ...
                any(data.S < 0) || any(data.Su < 0) || any(data.D < 0)
            error('OPUS:InvalidOwnerCounts', '%s must contain finite, nonnegative S, Su and D counts.', filename);
        end
        owners.S(data.shell, i) = data.S;
        owners.Su(data.shell, i) = data.Su;
        owners.D(data.shell, i) = data.D;
    end
    x0 = x0(:);
    if string(populationMode)=="additional"
        if any(strcmpi(owners.ids,'generic'))
            error('OPUS:ReservedGenericOwner', ...
                'Additional mode creates generic from the original population. Remove generic.csv or use a different ID for a genuinely additional owner.');
        end
        owners.ids{end+1}='generic';
        owners.S(:,end+1)=x0(1:n);
        owners.Su(:,end+1)=x0(3*n+1:4*n);
        owners.D(:,end+1)=x0(n+1:2*n);
        [owners.ids,order]=sort(owners.ids);
        owners.S=owners.S(:,order); owners.Su=owners.Su(:,order); owners.D=owners.D(:,order);
    end
    expected = [x0(1:n), x0(3*n+1:4*n), x0(n+1:2*n)];
    actual = [sum(owners.S, 2), sum(owners.Su, 2), sum(owners.D, 2)];
    if any(~isfinite(actual(:)))
        error('OPUS:InvalidOwnerCounts','Summed owner populations must be finite.');
    end
    initialState = [actual(:,1);actual(:,3);x0(2*n+1:3*n);actual(:,2)];
    if string(populationMode)=="additional", return; end
    tolerance = 1e-9 * max(1, abs(expected));
    [shell, species] = find(abs(actual - expected) > tolerance, 1);
    if ~isempty(shell)
        names = {'S', 'Su', 'D'};
        error('OPUS:OwnerTotalMismatch', ...
            'Owner %s counts in shell %d sum to %.15g; the initial state requires %.15g.', ...
            names{species}, shell, actual(shell, species), expected(shell, species));
    end
end
