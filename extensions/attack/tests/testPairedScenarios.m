function tests=testPairedScenarios
    tests=functiontests(localfunctions);
end

function setupOnce(t)
    ext=fileparts(fileparts(mfilename('fullpath')));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(ext));
    t.TestData.file=fullfile(ext,'examples','additional-constellations','additional-constellations.csv');
    t.TestData.pair=opusattack.runPairedScenarios(t.TestData.file,1,'');
end

function testMatchedControlSuppressesOnlyAttacks(t)
    p=t.TestData.pair; a=p.attacked; c=p.control;
    verifyEqual(t,a.parameters.x0,c.parameters.x0);
    verifyEqual(t,a.scenario.attack.owners,c.scenario.attack.owners);
    verifyEqual(t,a.scenario.attack.launch_rules,c.scenario.attack.launch_rules);
    verifyEqual(t,a.scenario.attack.owner_economics,c.scenario.attack.owner_economics);
    verifyEqual(t,numel(a.intervals),numel(c.intervals));
    for i=1:numel(a.intervals)
        verifyEqual(t,a.intervals{i}.T,c.intervals{i}.T);
    end
    verifyEqual(t,string(a.metadata.attack_mode),"scheduled");
    verifyEqual(t,string(c.metadata.attack_mode),"none");
    verifyEqual(t,c.metadata.configured_event_count,4);
    verifyEqual(t,c.metadata.applied_event_count,0);
    verifyEmpty(t,c.scenario.attack.events);
    verifyEmpty(t,c.fragmentations);
    verifyEmpty(t,c.disablings);
    verifyTrue(t,all(strcmp(a.launch_decisions.mode,'replacement')));
    verifyTrue(t,all(strcmp(c.launch_decisions.mode,'replacement')));
    verifyEqual(t,a.launch_decisions.launch_rate,c.launch_decisions.launch_rate);
    verifyEqual(t,a.history.S(1,:),c.history.S(1,:));
end

function testOwnerAndDebrisDifferencesAreAttributed(t)
    p=t.TestData.pair; o=p.comparison.owners; d=p.comparison.debris;
    verifyEqual(t,sort(o.owner_id),["generic";"kuiper-gen1";"starlink-gen1"]);
    verifyEqual(t,sum(o.fragmented),2);
    verifyEqual(t,sum(o.disabled),2);
    verifyEqual(t,o.fragmented(o.owner_id=="starlink-gen1"),1);
    verifyEqual(t,o.disabled(o.owner_id=="kuiper-gen1"),1);
    verifyEqual(t,o.delta_active,o.attacked_final_active-o.control_final_active,'AbsTol',1e-9);
    verifyEqual(t,o.delta_discounted_cash_flow_proxy, ...
        o.attacked_discounted_cash_flow_proxy-o.control_discounted_cash_flow_proxy,'AbsTol',1e-7);
    verifyEqual(t,d.delta_N,d.attacked_final_N-d.control_final_N,'AbsTol',1e-9);
    verifyGreaterThan(t,d.delta_N(10),0);
    verifyEqual(t,height(p.comparison.owner_shells),3*40);
end

function testExportAndInputValidation(t)
    folder=tempname; t.addTeardown(@() rmdir(folder,'s'));
    p=opusattack.runPairedScenarios(t.TestData.file,0.5,folder);
    verifyTrue(t,isfile(fullfile(folder,'attacked','result.mat')));
    verifyTrue(t,isfile(fullfile(folder,'control','result.mat')));
    verifyTrue(t,isfile(fullfile(folder,'owner-impact.csv')));
    verifyTrue(t,isfile(fullfile(folder,'owner-shell-impact.csv')));
    verifyTrue(t,isfile(fullfile(folder,'debris-impact.csv')));
    verifyTrue(t,isfile(fullfile(folder,'COMPLETE.txt')));
    verifyEqual(t,p.output_directory,folder);
    verifyEqual(t,p.control.metadata.applied_event_count,0);
    verifyEqual(t,p.attacked.metadata.applied_event_count,4);
    verifyError(t,@() opusattack.runPairedScenarios(t.TestData.file,0.5,folder), ...
        'OPUS:OutputAlreadyExists');
    verifyError(t,@() opusattack.runScenario(t.TestData.file,1,'','unknown'), ...
        'OPUS:InvalidAttackMode');
end

function testOneOwnerUsesOnlyItsEventsAgainstNoAttackControl(t)
    p=opusattack.runPairedScenarios(t.TestData.file,1,'',"starlink-gen1");
    verifyEqual(t,p.attacked.metadata.source_event_count,4);
    verifyEqual(t,p.attacked.metadata.configured_event_count,2);
    verifyEqual(t,p.control.metadata.configured_event_count,2);
    verifyEqual(t,p.control.metadata.applied_event_count,0);
    verifyEqual(t,p.attacked.fragmentations.owner_id,"starlink-gen1");
    verifyEqual(t,p.attacked.disablings.owner_id,"starlink-gen1");
    verifyEqual(t,p.comparison.owners.fragmented(p.comparison.owners.owner_id=="kuiper-gen1"),0);
    verifyEqual(t,p.comparison.owners.disabled(p.comparison.owners.owner_id=="kuiper-gen1"),0);
    verifyError(t,@() opusattack.runPairedScenarios(t.TestData.file,1,'',"missing-owner"), ...
        'OPUS:InvalidAttackOwner');
end

function testSameReplacementRuleRespondsAtNextAnnualDecision(t)
    p=opusattack.runPairedScenarios(t.TestData.file,2,'',"starlink-gen1");
    a=p.attacked.launch_decisions;
    c=p.control.launch_decisions;
    selected=strcmp(a.owner_id,'starlink-gen1') & a.shell==10 & ...
        strcmp(a.population,'S') & a.start_time==1;
    verifyEqual(t,sum(selected),1);
    verifyEqual(t,a.launch_rate(selected),a.current_count(selected)/p.attacked.parameters.Dt, ...
        'AbsTol',1e-10);
    verifyEqual(t,c.launch_rate(selected),c.current_count(selected)/p.control.parameters.Dt, ...
        'AbsTol',1e-10);
    verifyLessThan(t,a.launch_rate(selected),c.launch_rate(selected));
    verifyLessThan(t,p.comparison.owners.delta_launched( ...
        p.comparison.owners.owner_id=="starlink-gen1"),0);
end
