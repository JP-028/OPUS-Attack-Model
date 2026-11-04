function tests=testDisabling
    tests=functiontests(localfunctions);
end

function setupOnce(t)
    ext=fileparts(fileparts(mfilename('fullpath')));
    root=fileparts(fileparts(ext));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(ext));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'MOCAT4S')));
    t.TestData.ext=ext;
    t.TestData.file=fullfile(ext,'examples','mixed-attacks','mixed-attacks.csv');
    t.TestData.run=opusattack.runScenario(t.TestData.file,1,'');
end

function [o,N,e,V]=initial(t)
    r=t.TestData.run; V=r.parameters; o=r.scenario.attack.owners;
    N=V.x0(2*V.N_shell+1:3*V.N_shell);
    e=table2struct(r.scenario.attack.events(2,:));
end

function [file,events,folder]=temporaryScenario(t)
    folder=tempname; mkdir(folder); t.addTeardown(@() rmdir(folder,'s'));
    file=fullfile(folder,'case.csv');
    copyfile(t.TestData.file,file);
    copyfile(fullfile(t.TestData.ext,'examples','mixed-attacks','mixed-attacks-owners'),fullfile(folder,'case-owners'));
    copyfile(fullfile(t.TestData.ext,'examples','mixed-attacks','mixed-attacks-launches.csv'),fullfile(folder,'case-launches.csv'));
    events=t.TestData.run.scenario.attack.events;
    writetable(events,fullfile(folder,'case-events.csv'));
end

function testSameOwnerSameShellTransferAndMass(t)
    [o,N,e,V]=initial(t);
    [after,newN,report]=opusattack.applyDisabling(o,N,e,V);
    expected=o; expected.S(10,1)=expected.S(10,1)-100; expected.D(10,1)=expected.D(10,1)+100;
    verifyEqual(t,after,expected); verifyEqual(t,newN,N);
    verifyEqual(t,report.disabled_count,100);
    verifyEqual(t,report.transferred_mass_kg,22300);
    verifyEqual(t,report.mass_residual_kg,0);
    verifyEqual(t,report.object_count_residual,0);
    verifyEqual(t,report.satellite_area_m2,1.741);
    verifyEqual(t,report.satellite_diameter_m,1.490);
end

function testFringeSatelliteKeepsOwner(t)
    [o,N,e,V]=initial(t);
    e.population="Su"; e.owner_id="generic"; e.count=20;
    [after,newN]=opusattack.applyDisabling(o,N,e,V);
    expected=o; expected.Su(10,2)=o.Su(10,2)-20; expected.D(10,2)=o.D(10,2)+20;
    verifyEqual(t,after,expected); verifyEqual(t,newN,N);
end

function testDisabledPopulationDoesNotRetireOrRelocate(t)
    [o,N,e,V]=initial(t);
    o.S(:)=0; o.Su(:)=0; o.D(:)=0; N(:)=0;
    o.S(10,1)=100; V.k_star=1; V.phi(:)=0; V.beta(:)=0;
    [o,N]=opusattack.applyDisabling(o,N,e,V);
    launches=struct('S',zeros(size(o.S)),'Su',zeros(size(o.Su)));
    out=opusattack.propagateOwners([0,0.5,1],o,N,launches,V);
    verifyEqual(t,out.final.owners,o);
    verifyEqual(t,out.final.N,N);
    verifyEqual(t,out.final.owners.D(1,1),0);
end

function testDisabledPopulationNaturallyExitsLowestShell(t)
    [o,N,e,V]=initial(t);
    o.S(:)=0; o.Su(:)=0; o.D(:)=0; N(:)=0;
    e.shell=1; e.count=10; o.S(1,1)=10; V.phi(:)=0;
    [o,N]=opusattack.applyDisabling(o,N,e,V);
    launches=struct('S',zeros(size(o.S)),'Su',zeros(size(o.Su)));
    duration=0.001;
    out=opusattack.propagateOwners([0,duration/2,duration],o,N,launches,V);
    rate=densityexp(V.R02(1))*V.beta(2)*sqrt(V.mu*V.R0(1))*(24*3600*365.25)/V.Dhl;
    verifyEqual(t,out.final.owners.D(1,1),10*exp(-rate*duration),'AbsTol',1e-6);
    verifyLessThan(t,sum(out.D(end,:)),10);
    verifyEqual(t,out.final.owners.D(:,2),zeros(V.N_shell,1));
    hit=strcmp(out.flow_definition.process,'boundary_exit') & strcmp(out.flow_definition.owner_id,'attacked');
    verifyEqual(t,sum(out.cumulative_flows(end,hit)),10-sum(out.D(end,:)),'AbsTol',1e-7);
end

function testIncompatiblePhysicalPropertiesRejected(t)
    [o,N,e,V]=initial(t);
    for pop=["S","Su"]
        e.population=pop; e.owner_id="generic"; e.count=1;
        source=1; if pop=="Su", source=4; end
        for field={'mass','A','diameter','beta'}
            bad=V; bad.(field{1})(source)=bad.(field{1})(source)*2;
            verifyError(t,@() opusattack.applyDisabling(o,N,e,bad),'OPUS:IncompatibleDisablingPhysics');
        end
    end
end

function testInsufficientTargetsAndInvalidCounts(t)
    [o,N,e,V]=initial(t);
    e.count=o.S(10,1)+1;
    verifyError(t,@() opusattack.applyDisabling(o,N,e,V),'OPUS:InsufficientAttackTargets');
    e.count=1; o.S(10,1)=0.999;
    verifyError(t,@() opusattack.applyDisabling(o,N,e,V),'OPUS:InsufficientAttackTargets');
    [file,events,folder]=temporaryScenario(t);
    for count=[0,-1,1.5]
        bad=events; bad.count(2)=count;
        writetable(bad,fullfile(folder,'case-events.csv'));
        verifyError(t,@() opusattack.loadAttackEvents(file,o,V.N_shell),'OPUS:UnsupportedAttackSize');
    end
end

function testMixedScheduleHistoriesAndAccounting(t)
    r=t.TestData.run;
    verifyEqual(t,height(r.fragmentations),2); verifyEqual(t,height(r.disablings),3);
    verifyEqual(t,sum(r.disablings.disabled_count),121);
    verifyEqual(t,sum(r.fragmentations.debris_added),696.875);
    verifyLessThan(t,r.max_global_balance_residual,1e-5);
    verifyEqual(t,r.disablings.N_after,r.disablings.N_before);
    verifyEqual(t,r.disablings.active_before-r.disablings.active_after,r.disablings.disabled_count,'AbsTol',1e-10);
    verifyEqual(t,r.disablings.D_after-r.disablings.D_before,r.disablings.disabled_count,'AbsTol',1e-10);
    verifyEqual(t,r.history.phase(r.history.T==0.5),["pre_event";"post_event";"pre_event";"post_event"]);
    verifyEqual(t,r.attack_snapshots{2}.after,r.attack_snapshots{3}.before);
    verifyEqual(t,r.final,r.attack_snapshots{end}.after);
    events=r.events(strcmp(r.events.process,'disabling'),:);
    verifyEqual(t,events.source_count,events.destination_count);
    verifyEqual(t,events.owner_id,events.destination_owner_id);
    verifyEqual(t,events.shell,events.destination_shell);
    verifyTrue(t,all(strcmp(events.destination_population,'D')));
    verifyEqual(t,numel(unique(r.events.event_id)),height(r.events));
    verifyEqual(t,unique(r.launch_decisions.start_time),0);
    for i=2:numel(r.intervals)
        verifyEqual(t,r.intervals{i}.launches,r.intervals{1}.launches);
    end
end

function testAnnualDecisionsUseRemainingActiveSatellites(t)
    [file,events,folder]=temporaryScenario(t);
    events=events(2,:); events.time_year=0;
    second=events; second.event_id="disable-next"; second.time_year=1;
    writetable([events;second],fullfile(folder,'case-events.csv'));
    r=opusattack.runScenario(file,1.1,''); d=r.launch_decisions;
    hit=strcmp(d.owner_id,'attacked') & d.shell==10 & strcmp(d.population,'S');
    verifyEqual(t,d.current_count(hit & d.start_time==0),900);
    verifyEqual(t,d.current_count(hit & d.start_time==1),r.attack_snapshots{2}.after.owners.S(10,1));
    verifyLessThan(t,r.max_global_balance_residual,1e-5);
end

function testMixedSimultaneousOrderAndExhaustedTargets(t)
    [file,events,folder]=temporaryScenario(t);
    events=events([1,2],:); events.time_year(:)=0; events.count(2)=1000;
    writetable(events,fullfile(folder,'case-events.csv'));
    out=fullfile(folder,'output');
    verifyError(t,@() opusattack.runScenario(file,0.1,out),'OPUS:InsufficientAttackTargets');
    verifyFalse(t,isfolder(out));
    events.count(2)=999;
    writetable(events,fullfile(folder,'case-events.csv'));
    r=opusattack.runScenario(file,0.1,'');
    verifyEqual(t,r.attack_snapshots{2}.after.owners.S(10,1),0);
    verifyEqual(t,r.history.event_id(1:4),["attack:fragment-001";"attack:fragment-001";"attack:disable-001";"attack:disable-001"]);
    events=events([2,1],:);
    writetable(events,fullfile(folder,'case-events.csv'));
    reverse=opusattack.runScenario(file,0.1,'');
    verifyEqual(t,reverse.attack_snapshots{2}.after,r.attack_snapshots{2}.after);
    verifyEqual(t,reverse.history.event_id(1),"attack:disable-001");
end

function testExportsContainDisablingDetailsAndSnapshots(t)
    folder=tempname; mkdir(folder); t.addTeardown(@() rmdir(folder,'s'));
    out=fullfile(folder,'run'); r=t.TestData.run;
    opusattack.exportResults(r,out);
    details=readtable(fullfile(out,'disablings.csv'),'TextType','string');
    verifyEqual(t,details.disabled_count,[100;20;1]);
    h=readtable(fullfile(out,'owner-populations.csv'),'TextType','string');
    for i=1:height(details)
        rows=h(h.event_id==details.log_event_id(i) & h.shell==details.shell(i) & h.owner_id==details.owner_id(i),:);
        verifyEqual(t,rows.phase,["pre_event";"post_event"]);
        verifyEqual(t,rows.D(2)-rows.D(1),details.disabled_count(i),'AbsTol',1e-8);
    end
    saved=load(fullfile(out,'result.mat'),'result');
    verifyEqual(t,saved.result.disablings,r.disablings);
    verifyEqual(t,saved.result.attack_snapshots,r.attack_snapshots);
    verifyTrue(t,isfile(fullfile(out,'COMPLETE.txt')));
end

function testMixedContinuationMatchesOriginalMocat(t)
    r=t.TestData.run; V=r.parameters; n=V.N_shell; x=V.x0;
    events=r.scenario.attack.events; applied=false(height(events),1);
    old=warning; cleanup=onCleanup(@() warning(old)); %#ok<NASGU>
    for segment=1:numel(r.intervals)
        out=r.intervals{segment}; [x,applied]=jump(x,applied,out.T(1));
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
            state(index)=state(index)-events.count(row);
            if events.event_type(row)=="disabling"
                state(n+k)=state(n+k)+events.count(row);
            else
                state(2*n+k)=state(2*n+k)+V.mass(source)/V.mass(3);
            end
            done(row)=true;
        end
    end
end
