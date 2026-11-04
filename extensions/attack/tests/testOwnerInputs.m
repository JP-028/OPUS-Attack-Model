function tests = testOwnerInputs
    tests = functiontests(localfunctions);
end

function setupOnce(testCase)
    root = fileparts(fileparts(mfilename('fullpath')));
    testCase.applyFixture(matlab.unittest.fixtures.PathFixture(root));
end

function setup(testCase)
    folder = tempname;
    mkdir(folder);
    testCase.addTeardown(@() rmdir(folder, 's'));
    ownerFolder = fullfile(folder, 'scenario-owners');
    mkdir(ownerFolder);
    testCase.TestData.folder = ownerFolder;
    testCase.TestData.parset = fullfile(folder, 'scenario.csv');
    testCase.TestData.VAR = struct('N_shell', 3, ...
        'x0', [10;20;0; zeros(6,1); 3;4;5]);
    writeOwner(testCase, 'attacked', [1;2;3], [4;7;0], [0;0;0]);
    writeOwner(testCase, 'generic', [1;2;3], [6;13;0], [3;4;5]);
end

function writeOwner(t, id, shell, S, Su, D)
    if nargin < 6
        D = zeros(size(shell));
    end
    writetable(table(shell,S,Su,D), fullfile(t.TestData.folder, [id '.csv']));
end

function result = loadOwners(t)
    result = opusattack.loadOwners(t.TestData.parset, t.TestData.VAR);
end

function testValidOwnersAndRowOrder(t)
    writeOwner(t, 'attacked', [3;1;2], [0;4;7], [0;0;0]);
    result = loadOwners(t);
    verifyEqual(t, result.ids, {'attacked','generic'});
    verifyEqual(t, result.S, [4,6;7,13;0,0]);
    verifyEqual(t, sum(result.Su,2), [3;4;5]);
    verifyEqual(t, result.D, zeros(3,2));
end

function testFractionalExpectedCounts(t)
    writeOwner(t, 'attacked', [1;2;3], [4.5;7;0], [0;0;0]);
    writeOwner(t, 'generic', [1;2;3], [5.5;13;0], [3;4;5]);
    result = loadOwners(t);
    verifyEqual(t, sum(result.S,2), [10;20;0]);
end

function testMissingOwnerDirectory(t)
    verifyError(t, @() opusattack.loadOwners(fullfile(t.TestData.folder,'missing.csv'), ...
        t.TestData.VAR), 'OPUS:MissingOwnerFiles');
end

function testDuplicateShell(t)
    writeOwner(t, 'attacked', [1;1;3], [4;7;0], [0;0;0]);
    verifyError(t, @() loadOwners(t), 'OPUS:InvalidOwnerShells');
end

function testMissingShell(t)
    writeOwner(t, 'attacked', [1;2], [4;7], [0;0]);
    verifyError(t, @() loadOwners(t), 'OPUS:InvalidOwnerShells');
end

function testInvalidShellIndex(t)
    writeOwner(t, 'attacked', [0;2;3], [4;7;0], [0;0;0]);
    verifyError(t, @() loadOwners(t), 'OPUS:InvalidOwnerShells');
end

function testNegativeCount(t)
    writeOwner(t, 'attacked', [1;2;3], [-1;7;0], [0;0;0]);
    verifyError(t, @() loadOwners(t), 'OPUS:InvalidOwnerCounts');
end

function testMissingCount(t)
    writeOwner(t, 'attacked', [1;2;3], [NaN;7;0], [0;0;0]);
    verifyError(t, @() loadOwners(t), 'OPUS:InvalidOwnerCounts');
end

function testInfiniteCount(t)
    writeOwner(t, 'attacked', [1;2;3], [Inf;7;0], [0;0;0]);
    verifyError(t, @() loadOwners(t), 'OPUS:InvalidOwnerCounts');
end

function testIncompleteAllocation(t)
    writeOwner(t, 'attacked', [1;2;3], [3;7;0], [0;0;0]);
    verifyError(t, @() loadOwners(t), 'OPUS:OwnerTotalMismatch');
end

function testDoubleCounting(t)
    writeOwner(t, 'generic', [1;2;3], [10;20;0], [3;4;5]);
    verifyError(t, @() loadOwners(t), 'OPUS:OwnerTotalMismatch');
end

function testFringeMismatch(t)
    writeOwner(t, 'generic', [1;2;3], [6;13;0], [3;4;6]);
    verifyError(t, @() loadOwners(t), 'OPUS:OwnerTotalMismatch');
end

function testWrongColumns(t)
    writetable(table((1:3)', [4;7;0], 'VariableNames', {'shell','S'}), ...
        fullfile(t.TestData.folder,'attacked.csv'));
    verifyError(t, @() loadOwners(t), 'OPUS:InvalidOwnerColumns');
end

function testInvalidOwnerId(t)
    writeOwner(t, 'bad owner', [1;2;3], [0;0;0], [0;0;0]);
    verifyError(t, @() loadOwners(t), 'OPUS:InvalidOwnerId');
end

function testActualInitialStateTakesPrecedence(t)
    x0 = t.TestData.VAR.x0;
    x0(1) = 11;
    verifyError(t, @() opusattack.loadOwners(t.TestData.parset,t.TestData.VAR,x0), ...
        'OPUS:OwnerTotalMismatch');
end

function testBaselineNeedsNoOwnerFiles(t)
    [v,e,c,a] = opusattack.modifyParameters(struct,struct,struct,'benchmark');
    verifyFalse(t, a.enabled);
    verifyEqual(t, v, struct);
    verifyEqual(t, e, struct);
    verifyEqual(t, c, struct);
end

function testExampleMatchesRepositoryPopulation(t)
    extensionRoot = fileparts(fileparts(mfilename('fullpath')));
    root = fileparts(fileparts(extensionRoot));
    S = readmatrix(fullfile(root,'x0_TLE','Counts_PAYLOADslot_bins_35.csv'));
    Su = readmatrix(fullfile(root,'x0_TLE','Counts_PAYLOADunslot_bins_35.csv'));
    D = readmatrix(fullfile(root,'x0_TLE','Counts_DERELICT_bins_35.csv'));
    V = struct('N_shell',40,'x0',[S(:,2);D(:,2);zeros(40,1);Su(:,2)]);
    p = fullfile(extensionRoot,'examples','baseline','attack-example.csv');
    result = opusattack.loadOwners(p,V);
    verifyEqual(t, result.S(10,1), 1000);
    verifyEqual(t, sum(result.S,2), S(:,2));
    verifyEqual(t, sum(result.Su,2), Su(:,2));
    verifyEqual(t, result.D(:,1), zeros(40,1));
    verifyEqual(t, result.D(:,2), D(:,2));
    [~,~,~,a] = opusattack.modifyParameters(V,struct,struct,p);
    verifyTrue(t, a.enabled);
end

function testExtensionPreparationAndEnvironment(t)
    extensionRoot = fileparts(fileparts(mfilename('fullpath')));
    p = fullfile(extensionRoot,'examples','baseline','attack-example.csv');
    oldFolder = pwd;
    oldPath = path;
    scenario = opusattack.prepareScenario(p);
    verifyTrue(t, scenario.attack.enabled);
    verifyEqual(t, scenario.attack.owners.S(10,1), 1000);
    verifyEqual(t, sum(scenario.attack.owners.D,2), scenario.VAR.x0(41:80));
    verifyEqual(t, pwd, oldFolder);
    verifyEqual(t, path, oldPath);
    verifyEqual(t, height(scenario.attack.launch_rules), 2);
end

function testDisabledPreparation(t)
    scenario = opusattack.prepareScenario('benchmark');
    verifyFalse(t, scenario.attack.enabled);
    verifyFalse(t, isfield(scenario.attack, 'owners'));
    verifyError(t, @() opusattack.runScenario('benchmark'), 'OPUS:AttackNotEnabled');
end

function testEnvironmentRestoredOnValidationFailure(t)
    parameter_type = {'attack'};
    parameter_name = {'enabled'};
    parameter_value = 1;
    writetable(table(parameter_type,parameter_name,parameter_value), t.TestData.parset);
    oldFolder = pwd;
    oldPath = path;
    % This fixture has 3 rows per owner; the actual model requires 40.
    verifyError(t, @() opusattack.prepareScenario(t.TestData.parset), 'OPUS:InvalidOwnerShells');
    verifyEqual(t, pwd, oldFolder);
    verifyEqual(t, path, oldPath);
end

function testUnsupportedModel(t)
    verifyError(t, @() opusattack.prepareScenario('benchmark','GMPHD'), 'OPUS:UnsupportedAttackModel');
end

function testDerelictsSplitAcrossOwnersAndSortedByShell(t)
    t.TestData.VAR.x0(4:6) = [2;6;1];
    writeOwner(t, 'attacked', [3;1;2], [0;4;7], [0;0;0], [0;0.5;2]);
    writeOwner(t, 'generic', [1;2;3], [6;13;0], [3;4;5], [1.5;4;1]);
    result = loadOwners(t);
    verifyEqual(t, result.D, [0.5,1.5;2,4;0,1]);
    verifyEqual(t, sum(result.D,2), t.TestData.VAR.x0(4:6));
end

function testMissingDerelictColumn(t)
    % Old three-column files must be explicitly migrated, not inferred.
    writetable(table((1:3)', [4;7;0], zeros(3,1), ...
        'VariableNames', {'shell','S','Su'}), fullfile(t.TestData.folder,'attacked.csv'));
    verifyError(t, @() loadOwners(t), 'OPUS:InvalidOwnerColumns');
end

function testInvalidDerelictCounts(t)
    for invalid = [-1, NaN, Inf]
        writeOwner(t, 'attacked', [1;2;3], [4;7;0], [0;0;0], [invalid;0;0]);
        verifyError(t, @() loadOwners(t), 'OPUS:InvalidOwnerCounts');
    end
    writeOwner(t, 'attacked', [1;2;3], [4;7;0], [0;0;0], {'unknown';'0';'0'});
    verifyError(t, @() loadOwners(t), 'OPUS:InvalidOwnerCounts');
end

function testIncompleteDerelictAllocation(t)
    t.TestData.VAR.x0(4:6) = [2;6;1];
    writeOwner(t, 'generic', [1;2;3], [6;13;0], [3;4;5], [1;6;1]);
    verifyError(t, @() loadOwners(t), 'OPUS:OwnerTotalMismatch');
end

function testDoubleCountedDerelicts(t)
    t.TestData.VAR.x0(4:6) = [2;6;1];
    writeOwner(t, 'generic', [1;2;3], [6;13;0], [3;4;5], [2;6;1]);
    writeOwner(t, 'attacked', [1;2;3], [4;7;0], [0;0;0], [1;0;0]);
    verifyError(t, @() loadOwners(t), 'OPUS:OwnerTotalMismatch');
end

function testActualDerelictBaselineTakesPrecedence(t)
    x0 = t.TestData.VAR.x0;
    x0(4) = 1;
    verifyError(t, @() opusattack.loadOwners(t.TestData.parset,t.TestData.VAR,x0), ...
        'OPUS:OwnerTotalMismatch');
end

function testDocumentedTemplatesValidate(t)
    extensionRoot = fileparts(fileparts(mfilename('fullpath')));
    p = fullfile(extensionRoot,'templates','owner-scenario.csv');
    scenario = opusattack.prepareScenario(p);
    verifyTrue(t, scenario.attack.enabled);
    verifyEqual(t, scenario.attack.owners.ids, {'example-owner','generic-owner'});
    verifyEqual(t, scenario.attack.owners.S(10,:), [1000,1529]);
    verifyEqual(t, scenario.attack.owners.Su(10,:), [0,334]);
    verifyEqual(t, scenario.attack.owners.D(10,:), [0,2]);
    verifyEqual(t, scenario.VAR.Dt, scenario.econ_params.satLifetime);
end
