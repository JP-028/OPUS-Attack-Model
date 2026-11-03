function tests=testScenarioRun
    tests=functiontests(localfunctions);
end

function setupOnce(t)
    ext=fileparts(fileparts(mfilename('fullpath')));
    root=fileparts(fileparts(ext));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(ext));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(root));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'MOCAT4S')));
    t.TestData.file=fullfile(ext,'templates','owner-scenario.csv');
    t.TestData.run=opusattack.runScenario(t.TestData.file,2,'');
end

function testLaunchDecisionsUseCurrentOwnerCount(t)
    r=t.TestData.run;
    d=r.launch_decisions;
    first=d(strcmp(d.owner_id,'example-owner') & d.shell==10 & strcmp(d.population,'S'),:);
    verifyEqual(t,first.launch_rate(1),1500);
    current=r.intervals{1}.final.owners.S(10,1);
    verifyEqual(t,first.current_count(2),current);
    verifyEqual(t,first.launch_rate(2),min(1500,max(3000-current,0)),'AbsTol',1e-10);
    verifyNotEqual(t,first.launch_rate(1),first.launch_rate(2));
    owners=r.scenario.attack.owners;
    owners.S(10,2)=1e6; % Other owner's stock cannot replace this owner's stock.
    [launch,~]=opusattack.ownerLaunches(owners,r.scenario.attack.launch_rules,r.parameters,1);
    verifyEqual(t,launch.S(10,1),1500);
end

function testLaunchModesAndFractionalInterval(t)
    r=t.TestData.run; owners=r.scenario.attack.owners;
    rules=table(["example-owner";"generic-owner";"generic-owner";"example-owner"], ...
        [10;10;10;11],["S";"S";"Su";"S"],["target";"replacement";"fixed";"none"], ...
        [1100;0;0;0],[1500;10;15;0], 'VariableNames', ...
        {'owner_id','shell','population','mode','target_size','max_launch_rate'});
    launch=opusattack.ownerLaunches(owners,rules,r.parameters,0.5);
    verifyEqual(t,launch.S(10,1),200);
    verifyEqual(t,launch.S(10,2),10);
    verifyEqual(t,launch.Su(10,2),15);
    verifyEqual(t,launch.S(11,1),0);
end

function testFlowsBalanceOwnersAndDebris(t)
    r=t.TestData.run; f=r.flows; initial=r.scenario.attack.owners;
    verifyLessThan(t,r.max_balance_residual,1e-5);
    for i=1:numel(initial.ids)
        outgoing=sum(f.source_count(strcmp(f.owner_id,initial.ids{i})));
        incoming=sum(f.destination_count(strcmp(f.destination_owner_id,initial.ids{i})));
        before=sum(initial.S(:,i)+initial.Su(:,i)+initial.D(:,i));
        after=sum(r.final.owners.S(:,i)+r.final.owners.Su(:,i)+r.final.owners.D(:,i));
        verifyEqual(t,after,before+incoming-outgoing,'AbsTol',1e-5);
    end
    n=r.parameters.N_shell;
    initialN=sum(r.parameters.x0(2*n+1:3*n));
    incoming=sum(f.destination_count(strcmp(f.destination_population,'N')));
    outgoing=sum(f.source_count(strcmp(f.population,'N')));
    verifyEqual(t,sum(r.final.N),initialN+incoming-outgoing,'AbsTol',1e-5);
    for i=1:numel(r.intervals)
        o=r.intervals{i}; d=o.flow_definition;
        mask=strcmp(d.process,'launch');
        expected=sum(o.launches.S(:)+o.launches.Su(:))*(o.T(end)-o.T(1));
        verifyEqual(t,sum(o.cumulative_flows(end,mask)),expected,'AbsTol',1e-5);
    end
end

function testEventsAreAttributedIntervalRecords(t)
    r=t.TestData.run; e=r.events; p=r.event_participants;
    verifyEqual(t,numel(unique(e.event_id)),height(e));
    verifyTrue(t,all(isnan(e.event_time)));
    verifyFalse(t,any(ismember(e.process,{'drag_transfer','boundary_exit','retirement_to_derelict','retirement_removal'})));
    verifyTrue(t,all(ismember(p.event_id,e.event_id)));
    verifyTrue(t,all(ismember(p.owner_id,string(r.scenario.attack.owners.ids))));
    mixed=find(~cellfun(@isempty,e.counterpart_owner_id) & ~strcmp(e.owner_id,e.counterpart_owner_id),1);
    verifyNotEmpty(t,mixed);
    involved=p(p.event_id==e.event_id(mixed),:);
    verifyTrue(t,all(ismember(string({e.owner_id{mixed},e.counterpart_owner_id{mixed}}),involved.owner_id)));
end

function testAnnualLoopMatchesOriginalWithEquivalentLaunchInputs(t)
    r=t.TestData.run; V=r.parameters; state=V.x0;
    old=warning; cleanup=onCleanup(@() warning(old)); %#ok<NASGU>
    for i=1:numel(r.intervals)
        o=r.intervals{i}; launch=[sum(o.launches.S,2),sum(o.launches.Su,2)];
        reference=MOCAT4S(o.T,state,launch,V);
        for field={'S','D','N','Su'}
            a=o.(field{1}); b=reference.(field{1});
            verifyLessThan(t,max(abs(a(:)-b(:))./max(1,abs(b(:)))),3e-6);
        end
        state=[reference.S(end,:)';reference.D(end,:)';reference.N(end,:)';reference.Su(end,:)'];
    end
end

function testExportRoundTripAndNoOverwrite(t)
    folder=tempname; mkdir(folder);
    t.addTeardown(@() rmdir(folder,'s'));
    out=fullfile(folder,'run'); r=t.TestData.run;
    opusattack.exportResults(r,out);
    files={'result.mat','owner-populations.csv','shell-populations.csv','launch-decisions.csv', ...
        'flows.csv','events.csv','event-participants.csv','source-manifest.csv','diagnostics.csv','metadata.json','COMPLETE.txt'};
    for i=1:numel(files), verifyTrue(t,isfile(fullfile(out,files{i}))); end
    saved=load(fullfile(out,'result.mat'),'result');
    verifyEqual(t,saved.result.final,r.final);
    totals=readtable(fullfile(out,'shell-populations.csv'));
    verifyEqual(t,totals.N,r.history.N(:),'AbsTol',1e-5);
    owners=readtable(fullfile(out,'owner-populations.csv'));
    verifyEqual(t,owners.S,r.history.owners.S(:),'AbsTol',1e-5);
    verifyEqual(t,fileread(fullfile(out,'inputs','scenario.csv')),fileread(t.TestData.file));
    verifyTrue(t,isfile(fullfile(out,'inputs','launches.csv')));
    verifyError(t,@() opusattack.exportResults(r,out),'OPUS:OutputAlreadyExists');
end

function testDisabledScenarioDoesNotWriteOutputs(t)
    folder=tempname;
    verifyError(t,@() opusattack.runScenario('benchmark',1,folder),'OPUS:AttackNotEnabled');
    verifyFalse(t,isfolder(folder));
    verifyEqual(t,nargout('modifyParameters'),3); % Original upstream interface unchanged.
end

function testInvalidLaunchRulesRejected(t)
    folder=tempname; mkdir(folder); t.addTeardown(@() rmdir(folder,'s'));
    file=fullfile(folder,'case.csv'); rules=t.TestData.run.scenario.attack.launch_rules;
    rules.owner_id(1)="missing-owner";
    writetable(rules,fullfile(folder,'case-launches.csv'));
    owners=t.TestData.run.scenario.attack.owners;
    verifyError(t,@() opusattack.loadLaunchRules(file,owners,40),'OPUS:InvalidLaunchRules');
    rules=t.TestData.run.scenario.attack.launch_rules;
    writetable([rules;rules(1,:)],fullfile(folder,'case-launches.csv'));
    verifyError(t,@() opusattack.loadLaunchRules(file,owners,40),'OPUS:InvalidLaunchRules');
end
