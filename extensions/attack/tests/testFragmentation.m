function tests=testFragmentation
    tests=functiontests(localfunctions);
end

function setupOnce(t)
    ext=fileparts(fileparts(mfilename('fullpath')));
    root=fileparts(fileparts(ext));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(ext));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'MOCAT4S')));
    t.TestData.ext=ext;
    t.TestData.file=fullfile(ext,'examples','fragmentation','fragmentation.csv');
    t.TestData.scenario=opusattack.prepareScenario(t.TestData.file);
    t.TestData.run=opusattack.runScenario(t.TestData.file,1,'');
end

function [o,N,e,V]=initial(t)
    s=t.TestData.scenario;
    V=s.VAR; o=s.attack.owners;
    N=V.x0(2*V.N_shell+1:3*V.N_shell);
    e=table2struct(s.attack.events);
end

function [file,event,folder]=temporaryScenario(t,time)
    folder=tempname; mkdir(folder); t.addTeardown(@() rmdir(folder,'s'));
    file=fullfile(folder,'case.csv');
    copyfile(t.TestData.file,file);
    copyfile(fullfile(t.TestData.ext,'examples','fragmentation','fragmentation-owners'),fullfile(folder,'case-owners'));
    copyfile(fullfile(t.TestData.ext,'examples','fragmentation','fragmentation-launches.csv'),fullfile(folder,'case-launches.csv'));
    event=t.TestData.scenario.attack.events;
    event.time_year=time;
    writetable(event,fullfile(folder,'case-events.csv'));
end

function testExactOneSatelliteTransferAndMass(t)
    [o,N,e,V]=initial(t);
    [after,newN,report]=opusattack.applyFragmentation(o,N,e,V);
    expected=o; expected.S(10,1)=expected.S(10,1)-1;
    verifyEqual(t,after,expected);
    delta=zeros(size(N)); delta(10)=223/0.640;
    verifyEqual(t,newN-N,delta,'AbsTol',1e-10);
    verifyEqual(t,report.destroyed_count,1);
    verifyEqual(t,report.debris_added,348.4375);
    verifyEqual(t,report.removed_mass_kg,report.generated_mass_kg,'AbsTol',1e-12);
end

function testMassesComeFromSelectedPopulation(t)
    [o,N,e,V]=initial(t);
    e.population="Su"; e.owner_id="generic";
    V.mass(4)=250; V.mass(3)=0.5;
    [after,newN,report]=opusattack.applyFragmentation(o,N,e,V);
    verifyEqual(t,after.S,o.S);
    verifyEqual(t,after.Su(10,2),o.Su(10,2)-1);
    verifyEqual(t,newN(10)-N(10),500,'AbsTol',1e-10);
    verifyEqual(t,report.satellite_mass_kg,250);
end

function testLastSatelliteCanBeDestroyed(t)
    [o,N,e,V]=initial(t);
    o.S(10,1)=1;
    [after,newN]=opusattack.applyFragmentation(o,N,e,V);
    verifyEqual(t,after.S(10,1),0);
    V.k_star=t.TestData.run.parameters.k_star;
    launches=struct('S',zeros(size(o.S)),'Su',zeros(size(o.Su)));
    r=opusattack.propagateOwners([0,0.5,1],after,newN,launches,V);
    verifyEqual(t,r.final.owners.S(:,1),zeros(V.N_shell,1));
    verifyTrue(t,all(isfinite(r.total(:))));
end

function testInsufficientTargetsRejectedWithoutClamping(t)
    [o,N,e,V]=initial(t);
    o.S(10,1)=0.999;
    verifyError(t,@() opusattack.applyFragmentation(o,N,e,V),'OPUS:InsufficientAttackTargets');
    [file,event,folder]=temporaryScenario(t,0.5);
    event.shell=1; writetable(event,fullfile(folder,'case-events.csv'));
    out=fullfile(folder,'output');
    verifyError(t,@() opusattack.runScenario(file,1,out),'OPUS:InsufficientAttackTargets');
    verifyFalse(t,isfolder(out));
end

function testMidyearHistoryLogsAndUnchangedLaunchDecisions(t)
    r=t.TestData.run;
    hit=find(r.history.T==0.5);
    verifyEqual(t,numel(hit),2);
    verifyEqual(t,r.history.phase(hit),["pre_event";"post_event"]);
    verifyEqual(t,r.history.owners.S(hit(2),10,1)-r.history.owners.S(hit(1),10,1),-1,'AbsTol',1e-10);
    verifyEqual(t,r.history.N(hit(2),10)-r.history.N(hit(1),10),348.4375,'AbsTol',1e-10);
    verifyEqual(t,r.history.D(hit(2),:),r.history.D(hit(1),:));
    verifyEqual(t,r.history.total(hit(2),10)-r.history.total(hit(1),10),347.4375,'AbsTol',1e-9);
    verifyEqual(t,r.intervals{1}.launches,r.intervals{2}.launches);
    verifyEqual(t,unique(r.launch_decisions.start_time),0);
    e=r.events(strcmp(r.events.process,'fragmentation'),:);
    verifyEqual(t,height(e),1);
    verifyEqual(t,e.event_time,0.5);
    verifyEqual(t,e.record_kind,"instantaneous_attack");
    verifyEqual(t,e.source_count,1); verifyEqual(t,e.destination_count,348.4375);
    p=r.event_participants(r.event_participants.event_id==e.event_id,:);
    verifyEqual(t,p.owner_id,"attacked");
    verifyEqual(t,numel(unique(r.events.event_id)),height(r.events));
    verifyLessThan(t,r.max_global_balance_residual,1e-5);
end

function testAttackAtZeroPrecedesLaunchDecision(t)
    [file,~,~]=temporaryScenario(t,0);
    r=opusattack.runScenario(file,0.1,'');
    d=r.launch_decisions;
    hit=strcmp(d.owner_id,'attacked') & d.shell==10 & strcmp(d.population,'S');
    verifyEqual(t,d.current_count(hit),999);
    verifyEqual(t,r.history.phase(1:2),["pre_event";"post_event"]);
    verifyEqual(t,r.history.T(1:2),[0;0]);
    verifyEqual(t,height(r.fragmentations),1);
end

function testAttackAtAnnualBoundaryPrecedesNextDecision(t)
    [file,~,~]=temporaryScenario(t,1);
    r=opusattack.runScenario(file,1.1,'');
    snapshot=r.attack_snapshots{1};
    d=r.launch_decisions;
    hit=d.start_time==1 & strcmp(d.owner_id,'attacked') & d.shell==10 & strcmp(d.population,'S');
    verifyEqual(t,d.current_count(hit),snapshot.after.owners.S(10,1));
    verifyEqual(t,snapshot.before.owners.S(10,1)-snapshot.after.owners.S(10,1),1,'AbsTol',1e-10);
    verifyEqual(t,height(r.fragmentations),1);
end

function testAttackAtEndIncludedInFinalState(t)
    [file,~,~]=temporaryScenario(t,1);
    r=opusattack.runScenario(file,1,'');
    verifyEqual(t,r.final,r.attack_snapshots{1}.after);
    verifyEqual(t,r.history.phase(end),"post_event");
    verifyEqual(t,r.history.T(end-1:end),[1;1]);
    verifyEqual(t,unique(r.launch_decisions.start_time),0);
    verifyLessThan(t,r.max_global_balance_residual,1e-5);
end

function testTimeOutsideHorizonRejected(t)
    [file,~,folder]=temporaryScenario(t,2);
    out=fullfile(folder,'output');
    verifyError(t,@() opusattack.runScenario(file,1,out),'OPUS:EventOutsideHorizon');
    verifyFalse(t,isfolder(out));
end

function testMultipleSatellitesAndDuplicateEventIdsRejected(t)
    [file,event,folder]=temporaryScenario(t,0.5);
    o=t.TestData.scenario.attack.owners;
    event.count=2; writetable(event,fullfile(folder,'case-events.csv'));
    verifyError(t,@() opusattack.loadAttackEvents(file,o,40),'OPUS:UnsupportedAttackSize');
    event.count=1; writetable([event;event],fullfile(folder,'case-events.csv'));
    verifyError(t,@() opusattack.loadAttackEvents(file,o,40),'OPUS:DuplicateAttackEventId');
end

function testInvalidEventFieldsRejected(t)
    [file,event,folder]=temporaryScenario(t,0.5);
    o=t.TestData.scenario.attack.owners;
    cases={ 'owner_id',"unknown"; 'shell',41; 'shell',1.5; 'time_year',-1; ...
        'event_type',"unknown"; 'population',"D"; 'event_id',"invalid id"; 'time_year',NaN };
    for i=1:size(cases,1)
        bad=event; bad.(cases{i,1})=cases{i,2};
        writetable(bad,fullfile(folder,'case-events.csv'));
        verifyError(t,@() opusattack.loadAttackEvents(file,o,40),'OPUS:InvalidAttackEvents');
    end
end

function testNoEventsRemainEquivalentAndHaveSameIdentity(t)
    [file,event,folder]=temporaryScenario(t,0.5);
    delete(fullfile(folder,'case-events.csv'));
    absent=opusattack.runScenario(file,0.1,'');
    writetable(event([],:),fullfile(folder,'case-events.csv'));
    empty=opusattack.runScenario(file,0.1,'');
    verifyEqual(t,absent.history,empty.history);
    verifyEqual(t,absent.scenario.name,empty.scenario.name);
    verifyEmpty(t,empty.fragmentations);
    verifyTrue(t,all(empty.history.phase=="regular"));
    verifyFalse(t,strcmp(empty.scenario.name,t.TestData.scenario.name));
end

function testContinuationMatchesOriginalMocatWithManualJump(t)
    r=t.TestData.run; V=r.parameters;
    old=warning; cleanup=onCleanup(@() warning(old)); %#ok<NASGU>
    launch=r.intervals{1}.launches;
    lam=[sum(launch.S,2),sum(launch.Su,2)];
    first=MOCAT4S(linspace(0,0.5,5),V.x0,lam,V);
    x=[first.S(end,:)';first.D(end,:)';first.N(end,:)';first.Su(end,:)'];
    x(10)=x(10)-1;
    x(2*V.N_shell+10)=x(2*V.N_shell+10)+V.mass(1)/V.mass(3);
    reference=MOCAT4S(linspace(0.5,1,5),x,lam,V);
    for name={'S','D','N','Su'}
        actual=r.history.(name{1})(end,:); expected=reference.(name{1})(end,:);
        verifyLessThan(t,max(abs(actual-expected)./max(1,abs(expected))),3e-6);
    end
end

function testExportsPreserveAttackAndBothBoundaryStates(t)
    folder=tempname; mkdir(folder); t.addTeardown(@() rmdir(folder,'s'));
    out=fullfile(folder,'run'); r=t.TestData.run;
    opusattack.exportResults(r,out);
    details=readtable(fullfile(out,'fragmentations.csv'),'TextType','string');
    verifyEqual(t,details.debris_added,348.4375);
    totals=readtable(fullfile(out,'shell-populations.csv'),'TextType','string');
    hit=totals.time==0.5 & totals.shell==10;
    rows=totals(hit,:);
    verifyEqual(t,rows.phase,["pre_event";"post_event"]);
    verifyEqual(t,numel(unique(rows.sample_index)),2);
    verifyEqual(t,rows.N(2)-rows.N(1),348.4375,'AbsTol',1e-8);
    verifyTrue(t,isfile(fullfile(out,'inputs','events.csv')));
    verifyTrue(t,isfile(fullfile(out,'population-balance.csv')));
    saved=load(fullfile(out,'result.mat'),'result');
    verifyEqual(t,saved.result.attack_snapshots,r.attack_snapshots);
end

function testPhysicalOnlyWrapperCannotIgnoreEvents(t)
    verifyError(t,@() opusattack.propagateScenario(t.TestData.file,[0,1]),'OPUS:EventsRequireScenarioRunner');
end
