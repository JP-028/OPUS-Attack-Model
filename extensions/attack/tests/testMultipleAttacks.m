function tests=testMultipleAttacks
    tests=functiontests(localfunctions);
end

function setupOnce(t)
    ext=fileparts(fileparts(mfilename('fullpath')));
    root=fileparts(fileparts(ext));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(ext));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'MOCAT4S')));
    t.TestData.ext=ext;
    t.TestData.file=fullfile(ext,'examples','multiple-attacks','multiple-attacks.csv');
    t.TestData.run=opusattack.runScenario(t.TestData.file,1,'');
end

function [file,events,folder]=temporaryScenario(t)
    folder=tempname; mkdir(folder); t.addTeardown(@() rmdir(folder,'s'));
    file=fullfile(folder,'case.csv');
    copyfile(t.TestData.file,file);
    copyfile(fullfile(t.TestData.ext,'examples','multiple-attacks','multiple-attacks-owners'),fullfile(folder,'case-owners'));
    copyfile(fullfile(t.TestData.ext,'examples','multiple-attacks','multiple-attacks-launches.csv'),fullfile(folder,'case-launches.csv'));
    events=t.TestData.run.scenario.attack.events;
    writetable(events,fullfile(folder,'case-events.csv'));
end

function testChronologicalSortAndStableSameTimeOrder(t)
    [file,events,folder]=temporaryScenario(t);
    events=events([4,3,1,2],:);
    events.owner_id(1)="GENERIC";
    writetable(events,fullfile(folder,'case-events.csv'));
    loaded=opusattack.loadAttackEvents(file,t.TestData.run.scenario.attack.owners,40);
    verifyEqual(t,loaded.event_id,["attack-001";"attack-003";"attack-002";"attack-004"]);
    verifyEqual(t,loaded.time_year,[0.25;0.75;0.75;1]);
    verifyEqual(t,loaded.owner_id(end),"generic");
end

function testEveryAttackExecutedAndBalanced(t)
    r=t.TestData.run; f=r.fragmentations;
    verifyEqual(t,height(f),4);
    verifyEqual(t,f.event_id,r.scenario.attack.events.event_id);
    verifyEqual(t,f.active_after-f.active_before,-ones(4,1),'AbsTol',1e-10);
    verifyEqual(t,f.N_after-f.N_before,repmat(348.4375,4,1),'AbsTol',1e-10);
    verifyEqual(t,f.D_after,f.D_before);
    verifyEqual(t,sum(f.destroyed_count),4);
    verifyEqual(t,sum(f.debris_added),1393.75);
    verifyEqual(t,sum(f.removed_mass_kg),892);
    verifyEqual(t,f.mass_residual_kg,zeros(4,1),'AbsTol',1e-12);
    verifyLessThan(t,r.max_global_balance_residual,1e-5);
    verifyEqual(t,numel(unique(r.events.event_id)),height(r.events));
    for i=1:height(f)
        snapshot=r.attack_snapshots{i};
        owner=find(strcmp(snapshot.before.owners.ids,f.owner_id(i)));
        expected=snapshot.before;
        expected.owners.(char(f.population(i)))(f.shell(i),owner)= ...
            expected.owners.(char(f.population(i)))(f.shell(i),owner)-1;
        expected.N(f.shell(i))=expected.N(f.shell(i))+f.debris_added(i);
        verifyEqual(t,snapshot.after,expected);
    end
end

function testSimultaneousHistoryPreservesBothEvents(t)
    r=t.TestData.run;
    hit=find(r.history.T==0.75);
    verifyEqual(t,numel(hit),4);
    verifyEqual(t,r.history.phase(hit),["pre_event";"post_event";"pre_event";"post_event"]);
    verifyEqual(t,r.history.event_id(hit),["attack:attack-002";"attack:attack-002"; ...
        "attack:attack-003";"attack:attack-003"]);
    for pop={'S','Su','D','N'}
        values=r.history.(pop{1});
        verifyEqual(t,values(hit(2),:),values(hit(3),:));
    end
    verifyEqual(t,r.attack_snapshots{2}.after,r.attack_snapshots{3}.before);
    verifyEqual(t,unique(r.launch_decisions.start_time),0);
    for i=2:numel(r.intervals)
        verifyEqual(t,r.intervals{i}.launches,r.intervals{1}.launches);
    end
end

function testSameOwnerAttacksAtZeroAndBeforeAnnualDecision(t)
    [file,events,folder]=temporaryScenario(t);
    events=events(1:3,:);
    events.time_year=[0;0;1]; events.owner_id(:)="attacked";
    events.shell(:)=10; events.population(:)="S";
    writetable(events,fullfile(folder,'case-events.csv'));
    r=opusattack.runScenario(file,1.1,'');
    d=r.launch_decisions;
    selected=strcmp(d.owner_id,'attacked') & d.shell==10 & strcmp(d.population,'S');
    verifyEqual(t,d.current_count(selected & d.start_time==0),998);
    verifyEqual(t,d.current_count(selected & d.start_time==1),r.attack_snapshots{3}.after.owners.S(10,1));
    verifyEqual(t,height(r.fragmentations),3);
    verifyEqual(t,r.history.phase(1:4),["pre_event";"post_event";"pre_event";"post_event"]);
    verifyLessThan(t,r.max_global_balance_residual,1e-5);
end

function testLaterAttackCannotUseAlreadyDestroyedSatellite(t)
    [file,events,folder]=temporaryScenario(t);
    events=events(1:2,:); events.time_year(:)=0;
    writetable(events,fullfile(folder,'case-events.csv'));
    target=fullfile(folder,'case-owners','attacked.csv');
    generic=fullfile(folder,'case-owners','generic.csv');
    a=readtable(target); g=readtable(generic);
    a.S(a.shell==10)=1; g.S(g.shell==10)=2528;
    writetable(a,target); writetable(g,generic);
    out=fullfile(folder,'output');
    verifyError(t,@() opusattack.runScenario(file,0.1,out),'OPUS:InsufficientAttackTargets');
    verifyFalse(t,isfolder(out));
end

function testEveryScheduleRowIsValidated(t)
    [file,events,folder]=temporaryScenario(t);
    owners=t.TestData.run.scenario.attack.owners;
    cases={'time_year',-1;'shell',41;'owner_id',"unknown";'population',"D"; ...
        'event_type',"unknown";'event_id',"bad id"};
    for i=1:size(cases,1)
        bad=events; bad.(cases{i,1})(end)=cases{i,2};
        writetable(bad,fullfile(folder,'case-events.csv'));
        verifyError(t,@() opusattack.loadAttackEvents(file,owners,40),'OPUS:InvalidAttackEvents');
    end
    events.count(end)=2; writetable(events,fullfile(folder,'case-events.csv'));
    verifyError(t,@() opusattack.loadAttackEvents(file,owners,40),'OPUS:UnsupportedAttackSize');
    events.count(end)=1; events.time_year(end)=2;
    writetable(events,fullfile(folder,'case-events.csv'));
    verifyError(t,@() opusattack.runScenario(file,1,''),'OPUS:EventOutsideHorizon');
end

function testDuplicateEventIdsRejectedIgnoringCase(t)
    [file,events,folder]=temporaryScenario(t);
    events.event_id(end)=upper(events.event_id(1));
    writetable(events,fullfile(folder,'case-events.csv'));
    owners=t.TestData.run.scenario.attack.owners;
    verifyError(t,@() opusattack.loadAttackEvents(file,owners,40),'OPUS:DuplicateAttackEventId');
end

function testExportHasBeforeAndAfterForEveryAttack(t)
    folder=tempname; mkdir(folder); t.addTeardown(@() rmdir(folder,'s'));
    out=fullfile(folder,'run'); r=t.TestData.run;
    opusattack.exportResults(r,out);
    details=readtable(fullfile(out,'fragmentations.csv'),'TextType','string');
    totals=readtable(fullfile(out,'shell-populations.csv'),'TextType','string');
    events=readtable(fullfile(out,'events.csv'),'TextType','string');
    verifyEqual(t,height(details),4);
    for i=1:height(details)
        rows=totals(totals.event_id==details.log_event_id(i) & totals.shell==details.shell(i),:);
        verifyEqual(t,rows.phase,["pre_event";"post_event"]);
        verifyEqual(t,rows.N(2)-rows.N(1),348.4375,'AbsTol',1e-8);
        verifyEqual(t,sum(events.event_id==details.log_event_id(i)),1);
    end
    verifyEqual(t,fileread(fullfile(out,'inputs','events.csv')), ...
        fileread(fullfile(t.TestData.ext,'examples','multiple-attacks','multiple-attacks-events.csv')));
end

function testMultipleJumpsMatchOriginalMocat(t)
    r=t.TestData.run; V=r.parameters; n=V.N_shell; x=V.x0;
    events=r.scenario.attack.events; applied=false(height(events),1);
    old=warning; cleanup=onCleanup(@() warning(old)); %#ok<NASGU>
    for segment=1:numel(r.intervals)
        out=r.intervals{segment};
        [x,applied]=jump(x,applied,out.T(1));
        lam=[sum(out.launches.S,2),sum(out.launches.Su,2)];
        reference=MOCAT4S(out.T,x,lam,V);
        for pop={'S','D','N','Su'}
            a=out.(pop{1}); b=reference.(pop{1});
            verifyLessThan(t,max(abs(a(:)-b(:))./max(1,abs(b(:)))),3e-6);
        end
        x=[reference.S(end,:)';reference.D(end,:)';reference.N(end,:)';reference.Su(end,:)'];
    end
    [x,applied]=jump(x,applied,r.history.T(end));
    actual=[sum(r.final.owners.S,2);sum(r.final.owners.D,2);r.final.N;sum(r.final.owners.Su,2)];
    verifyTrue(t,all(applied));
    verifyLessThan(t,max(abs(actual-x)./max(1,abs(x))),3e-6);
    function [state,done]=jump(state,done,time)
        for row=find(events.time_year==time & ~done)'
            k=events.shell(row); source=1; index=k;
            if events.population(row)=="Su", source=4; index=3*n+k; end
            state(index)=state(index)-1;
            state(2*n+k)=state(2*n+k)+V.mass(source)/V.mass(3);
            done(row)=true;
        end
    end
end
