function tests = testOwnerPropagation
    tests = functiontests(localfunctions);
end

function setupOnce(t)
    extensionRoot = fileparts(fileparts(mfilename('fullpath')));
    root = fileparts(fileparts(extensionRoot));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(extensionRoot));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(root));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'MOCAT4S')));
    p = fullfile(extensionRoot,'templates','owner-scenario.csv');
    scenario = opusattack.prepareScenario(p);
    V = scenario.VAR;
    costs = buildCostFunction(V,scenario.econ_params);
    V.k_star = costs.k_star;
    t.TestData.V = V;
    t.TestData.owners = scenario.attack.owners;
    t.TestData.N = V.x0(2*V.N_shell+1:3*V.N_shell);
    t.TestData.parameterFile = p;
end

function testMatchesOriginalMocat(t)
    V = t.TestData.V;
    owners = t.TestData.owners;
    launch = struct('S', owners.S/V.Dt, 'Su', owners.Su/V.Dt);
    times = linspace(0,1,5);
    actual = opusattack.propagateOwners(times,owners,t.TestData.N,launch,V);
    reference = originalRun(times,owners,t.TestData.N,launch,V);
    verifyAggregates(t,actual,reference);
end

function testMatchesOriginalWithAllCollisionTerms(t)
    V = t.TestData.V;
    V.slot_par = 0.4;
    V.P = 0.25;
    owners = t.TestData.owners;
    % Populate both classes in every shell to exercise active cross terms.
    owners.S = owners.S+10;
    owners.Su = owners.Su+5;
    launch = struct('S',ones(size(owners.S))*2,'Su',ones(size(owners.Su)));
    times = linspace(0,1,5);
    actual = opusattack.propagateOwners(times,owners,t.TestData.N,launch,V);
    reference = originalRun(times,owners,t.TestData.N,launch,V);
    verifyAggregates(t,actual,reference);
end

function reference = originalRun(times,owners,N,launch,V)
    % Upstream MOCAT disables warnings globally; restore them after the reference.
    oldWarnings = warning;
    cleanup = onCleanup(@() warning(oldWarnings)); %#ok<NASGU>
    x = [sum(owners.S,2);sum(owners.D,2);N;sum(owners.Su,2)];
    reference = MOCAT4S(times,x,[sum(launch.S,2),sum(launch.Su,2)],V);
end

function verifyAggregates(t,actual,expected)
    for field = {'S','D','Su','N'}
        a = actual.(field{1}); b = expected.(field{1});
        % Compare differently sized ODE systems at common reporting times.
        scaledError = max(abs(a(:)-b(:))./max(1,abs(b(:))));
        verifyLessThan(t,scaledError,2e-6,field{1});
    end
end

function testSplittingOwnerPreservesTotalsAndThirtyPercentShare(t)
    V = t.TestData.V;
    original = t.TestData.owners;
    merged = struct('ids',{{'merged'}},'S',sum(original.S,2), ...
        'D',sum(original.D,2),'Su',sum(original.Su,2));
    split = struct('ids',{{'owner-a','owner-b'}},'S',merged.S*[0.3,0.7], ...
        'D',merged.D*[0.3,0.7],'Su',merged.Su*[0.3,0.7]);
    singleLaunch = struct('S',merged.S/V.Dt,'Su',merged.Su/V.Dt);
    splitLaunch = struct('S',singleLaunch.S*[0.3,0.7],'Su',singleLaunch.Su*[0.3,0.7]);
    a = opusattack.propagateOwners([0,0.5,1],merged,t.TestData.N,singleLaunch,V);
    b = opusattack.propagateOwners([0,0.5,1],split,t.TestData.N,splitLaunch,V);
    verifyAggregates(t,b,a);
    for field = {'S','D','Su'}
        values = b.owners.(field{1});
        verifyEqual(t,values(:,:,1),0.3*b.(field{1}),'AbsTol',1e-7,'RelTol',1e-7);
    end
end

function [o,launch,V] = emptyState(t)
    V = t.TestData.V;
    z = zeros(V.N_shell,2);
    o = struct('ids',{{'owner-a','owner-b'}},'S',z,'D',z,'Su',z);
    launch = struct('S',z,'Su',z);
end

function testCompletelyEmptySystem(t)
    [o,launch,V] = emptyState(t);
    result = opusattack.propagateOwners([0,0.5,1],o,zeros(V.N_shell,1),launch,V);
    verifyEqual(t,result.total,zeros(3,V.N_shell));
end

function testEmptyOwnerStaysEmpty(t)
    V = t.TestData.V;
    o = t.TestData.owners;
    o.ids{3} = 'empty';
    for field = {'S','D','Su'}
        o.(field{1})(:,3) = 0;
    end
    launch = struct('S',zeros(size(o.S)),'Su',zeros(size(o.Su)));
    r = opusattack.propagateOwners([0,0.5,1],o,t.TestData.N,launch,V);
    for field = {'S','D','Su'}
        values = r.owners.(field{1});
        verifyEqual(t,values(:,:,3),zeros(3,V.N_shell));
    end
end

function testLaunchIntoEmptyShellHasCorrectOwnerAndRetirement(t)
    [o,launch,V] = emptyState(t);
    V.beta(:) = 0; V.phi(:) = 0; V.k_star = V.N_shell;
    launch.S(10,1) = 100;
    launch.Su(12,2) = 50;
    r = opusattack.propagateOwners([0,0.5,1],o,zeros(V.N_shell,1),launch,V);
    expectedS = 100*V.Dt*(1-exp(-1/V.Dt));
    expectedSu = 50*V.Dt*(1-exp(-1/V.Dt));
    verifyEqual(t,r.final.owners.S(10,1),expectedS,'AbsTol',1e-6);
    verifyEqual(t,r.final.owners.Su(12,2),expectedSu,'AbsTol',1e-6);
    verifyEqual(t,r.final.owners.D(10,1),100-expectedS,'AbsTol',1e-6);
    verifyEqual(t,r.final.owners.D(12,2),50-expectedSu,'AbsTol',1e-6);
    verifyEqual(t,r.final.owners.S(:,2),zeros(V.N_shell,1));
    verifyEqual(t,r.final.owners.Su(:,1),zeros(V.N_shell,1));
end

function testRetirementRelocatesButExistingDerelictsDoNot(t)
    [o,launch,V] = emptyState(t);
    V.beta(:) = 0; V.phi(:) = 0; V.k_star = 5;
    o.S(20,1) = 100;
    o.Su(3,2) = 50;
    o.D(30,1) = 20;
    r = opusattack.propagateOwners([0,0.5,1],o,zeros(V.N_shell,1),launch,V);
    verifyEqual(t,r.final.owners.D(5,1),100*(1-exp(-1/V.Dt)),'AbsTol',1e-6);
    verifyEqual(t,r.final.owners.D(3,2),50*(1-exp(-1/V.Dt)),'AbsTol',1e-6);
    verifyEqual(t,r.final.owners.D(30,1),20,'AbsTol',1e-8);
    verifyEqual(t,r.final.owners.D(20,1),0,'AbsTol',1e-8);
end

function testDerelictDragPreservesOwnerAndLeavesLowestShell(t)
    [o,launch,V] = emptyState(t);
    V.phi(:) = 0;
    o.D(1,1) = 30; o.D(1,2) = 70;
    duration = 0.001;
    r = opusattack.propagateOwners([0,duration/2,duration],o,zeros(V.N_shell,1),launch,V);
    rate = densityexp(V.R02(1))*V.beta(2)*sqrt(V.mu*V.R0(1)) ...
        *(24*3600*365.25)/V.Dhl;
    verifyEqual(t,r.final.owners.D(1,:),[30,70]*exp(-rate*duration),'AbsTol',1e-6);
    verifyLessThan(t,sum(r.D(end,:)),100);
    verifyEqual(t,r.final.owners.D(2:end,:),zeros(V.N_shell-1,2));
end

function testDamageCreatesDerelictsForAffectedActiveOwner(t)
    [o,launch,V] = emptyState(t);
    V.beta(:)=0; V.phi(:)=0; V.K0(:)=0;
    V.P=1; V.alpha=0; V.delta=1;
    V.phi(1,3)=V.V(10)*0.01;
    o.S(10,:) = [30,70];
    N = zeros(V.N_shell,1); N(10)=10;
    r = opusattack.propagateOwners([0,0.5,1],o,N,launch,V);
    hazard = 1/V.Dt + 0.1;
    expectedD = [30,70]*0.1/hazard*(1-exp(-hazard));
    verifyEqual(t,r.final.owners.D(10,:),expectedD,'AbsTol',1e-6);
    verifyEqual(t,r.final.N,N,'AbsTol',1e-8);
end

function testOtherOwnersDerelictsAffectActiveSatellites(t)
    [o,launch,V] = emptyState(t);
    V.beta(:)=0; V.phi(:)=0; V.K0(:)=0;
    V.P=1; V.delta=0; V.alpha=1;
    V.phi(1,2)=V.V(10)*0.001;
    o.S(10,1)=100; o.D(10,2)=100;
    N=zeros(V.N_shell,1);
    r=opusattack.propagateOwners([0,0.5,1],o,N,launch,V);
    verifyEqual(t,r.final.owners.S(10,1),100*exp(-(1/V.Dt+0.1)),'AbsTol',1e-6);
    verifyEqual(t,r.final.owners.D(10,2),100,'AbsTol',1e-8);
    verifyEqual(t,r.final.owners.D(:,1),zeros(V.N_shell,1));
end

function testSlottedProtectionRemainsEnabled(t)
    [o,launch,V] = emptyState(t);
    V.beta(:)=0; V.phi(:)=0; V.P=1;
    V.phi(1,1)=V.V(10);
    o.S(10,:)=[30,70];
    r=opusattack.propagateOwners([0,0.5,1],o,zeros(V.N_shell,1),launch,V);
    verifyEqual(t,r.final.owners.S(10,:),[30,70]*exp(-1/V.Dt),'AbsTol',1e-6);
    verifyEqual(t,r.final.N,zeros(V.N_shell,1));
end

function testRestartMatchesContinuousPropagation(t)
    V=t.TestData.V; o=t.TestData.owners;
    launch=struct('S',o.S/V.Dt,'Su',o.Su/V.Dt);
    whole=opusattack.propagateOwners([0,1,2],o,t.TestData.N,launch,V);
    first=opusattack.propagateOwners([0,0.5,1],o,t.TestData.N,launch,V);
    second=opusattack.propagateOwners([1,1.5,2],first.final.owners,first.final.N,launch,V);
    for field={'S','D','Su','N'}
        a=whole.(field{1}); b=second.(field{1});
        verifyEqual(t,b(end,:),a(end,:),'AbsTol',1e-5,'RelTol',2e-6);
    end
end

function testInvalidStateAndLaunchesAreRejected(t)
    [o,launch,V]=emptyState(t);
    N=zeros(V.N_shell,1);
    o.S(1,1)=-1;
    verifyError(t,@() opusattack.propagateOwners([0,1],o,N,launch,V),'OPUS:InvalidOwnerState');
    o.S(1,1)=0; launch.S(1,1)=NaN;
    verifyError(t,@() opusattack.propagateOwners([0,1],o,N,launch,V),'OPUS:InvalidOwnerLaunches');
    launch.S(1,1)=0;
    verifyError(t,@() opusattack.propagateOwners([0,0],o,N,launch,V),'OPUS:InvalidTimeSpan');
end

function testScenarioWrapperAndLargeDebrisPopulation(t)
    oldPath=path; oldFolder=pwd;
    result=opusattack.propagateScenario(t.TestData.parameterFile,[0,0.5,1]);
    verifyEqual(t,result.owners.ids,t.TestData.owners.ids);
    verifyEqual(t,result.launches.S,zeros(size(t.TestData.owners.S)));
    verifyEqual(t,path,oldPath); verifyEqual(t,pwd,oldFolder);
    N=t.TestData.N; N(11)=N(11)+350000;
    o=t.TestData.owners; V=t.TestData.V;
    launch=struct('S',o.S/V.Dt,'Su',o.Su/V.Dt);
    high=opusattack.propagateOwners([0,0.5,1],o,N,launch,V);
    verifyTrue(t,all(isfinite(high.total(:))));
    verifyGreaterThanOrEqual(t,min(high.total(:)),0);
end
