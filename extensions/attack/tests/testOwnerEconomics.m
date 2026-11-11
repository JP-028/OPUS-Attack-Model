function tests=testOwnerEconomics
    tests=functiontests(localfunctions);
end

function setupOnce(t)
    ext=fileparts(fileparts(mfilename('fullpath')));
    root=fileparts(fileparts(ext));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(ext));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'MOCAT4S')));
    t.TestData.ext=ext;
end

function [file,folder]=scenario(t)
    folder=tempname; mkdir(folder); t.addTeardown(@() rmdir(folder,'s'));
    file=fullfile(folder,'case.csv');
    copyfile(fullfile(t.TestData.ext,'examples','baseline','attack-example.csv'),file);
    copyfile(fullfile(t.TestData.ext,'examples','baseline','attack-example-owners'), ...
        fullfile(folder,'case-owners'));
end

function testOwnerCostChangesEconomicLaunchDecision(t)
    [file,folder]=scenario(t);
    owner_id="generic"; shell=10; population="Su"; mode="economic";
    target_size=0; max_launch_rate=100;
    writetable(table(owner_id,shell,population,mode,target_size,max_launch_rate), ...
        fullfile(folder,'case-launches.csv'));
    cost_multiplier=0.25;
    writetable(table(owner_id,cost_multiplier),fullfile(folder,'case-economics.csv'));
    low=opusattack.runScenario(file,0.1,'');
    cost_multiplier=4;
    writetable(table(owner_id,cost_multiplier),fullfile(folder,'case-economics.csv'));
    high=opusattack.runScenario(file,0.1,'');
    lowRate=low.economic_decisions.launch_rate(1);
    highRate=high.economic_decisions.launch_rate(1);
    verifyGreaterThan(t,lowRate,highRate);
    verifyEqual(t,highRate,0);
    verifyLessThanOrEqual(t,lowRate,100);
    verifyEqual(t,low.economic_decisions.deployment_cost_per_satellite(1)*16, ...
        high.economic_decisions.deployment_cost_per_satellite(1),'RelTol',1e-10);
    verifyEqual(t,low.economic_decisions.owner_id,"generic");
    verifyEqual(t,low.economic_decisions.population,"Su");
    verifyEqual(t,low.economic_decisions.projected_revenue_per_satellite_year(1), ...
        low.scenario.econ_params.intercept-low.scenario.econ_params.coef* ...
        sum(low.intervals{1}.Su(end,:)),'AbsTol',5e3);
end

function testSlottedOwnerCanChooseEconomicLaunches(t)
    [file,folder]=scenario(t);
    owner_id="attacked"; shell=10; population="S"; mode="economic";
    target_size=0; max_launch_rate=100;
    writetable(table(owner_id,shell,population,mode,target_size,max_launch_rate), ...
        fullfile(folder,'case-launches.csv'));
    cost_multiplier=0.25;
    writetable(table(owner_id,cost_multiplier),fullfile(folder,'case-economics.csv'));
    low=opusattack.runScenario(file,0.1,'');
    verifyGreaterThan(t,low.economic_decisions.launch_rate,0);
    verifyLessThanOrEqual(t,low.economic_decisions.launch_rate,100);
    verifyEqual(t,low.economic_decisions.population,"S");
    verifyTrue(t,isfinite(low.economic_decisions.projected_collision_probability));
end

function testTwoOwnersMakeSeparateEconomicChoices(t)
    [file,folder]=scenario(t);
    owner_id=["attacked";"generic"]; shell=[10;10]; population=["S";"Su"];
    mode=["economic";"economic"]; target_size=[0;0]; max_launch_rate=[50;50];
    writetable(table(owner_id,shell,population,mode,target_size,max_launch_rate), ...
        fullfile(folder,'case-launches.csv'));
    cost_multiplier=[10;0.25];
    writetable(table(owner_id,cost_multiplier),fullfile(folder,'case-economics.csv'));
    r=opusattack.runScenario(file,0.1,'');
    d=r.economic_decisions;
    verifyEqual(t,height(d),2);
    verifyEqual(t,d.launch_rate(1),0);
    verifyGreaterThan(t,d.launch_rate(2),0);
    verifyEqual(t,r.intervals{1}.launches.S(10,1),0);
    verifyEqual(t,r.intervals{1}.launches.Su(10,2),d.launch_rate(2));
    verifyEqual(t,d.projected_revenue_per_satellite_year(1), ...
        d.projected_revenue_per_satellite_year(2));
end

function testRevenueAndSpendingAreAttributedToOwners(t)
    [file,folder]=scenario(t);
    r=opusattack.runScenario(file,0.25,'');
    e=r.owner_economics;
    verifyEqual(t,height(e),2*r.parameters.N_shell*numel(r.scenario.attack.owners.ids));
    verifyEqual(t,e.cash_flow_proxy,e.modeled_revenue-e.launch_spending,'AbsTol',1e-7);
    verifyEqual(t,e.nominal_collision_asset_value, ...
        e.collision_loss_count.*e.deployment_cost_per_satellite,'AbsTol',1e-7);
    verifyEqual(t,e.discounted_cash_flow_proxy, ...
        e.discounted_revenue-e.discounted_launch_spending,'AbsTol',1e-7);
    verifyTrue(t,all(e.discounted_cash_flow_proxy<=e.cash_flow_proxy | e.cash_flow_proxy<0));
    verifyEqual(t,sort(unique(e.owner_id)),["attacked";"generic"]);
    verifyTrue(t,all(isfinite(e.modeled_revenue)));
    out=fullfile(folder,'export'); opusattack.exportResults(r,out);
    verifyTrue(t,isfile(fullfile(out,'owner-economics.csv')));
    verifyTrue(t,isfile(fullfile(out,'economic-decisions.csv')));
    verifyTrue(t,isfile(fullfile(out,'attack-economics.csv')));
end

function testInvalidSharedEconomicInputsStopBeforeSimulation(t)
    [file,~]=scenario(t);
    p=readtable(file);
    p(end+1,:)={'econ','discountRate',-1};
    writetable(p,file);
    verifyError(t,@() opusattack.runScenario(file,0.1,''),'MATLAB:expectedNonnegative');
end

function testAttackCostIsLabeledNominalAndRetainsOwner(t)
    file=fullfile(t.TestData.ext,'examples','fragmentation','fragmentation.csv');
    r=opusattack.runScenario(file,0.5,'');
    e=r.attack_economics;
    verifyEqual(t,height(e),1);
    verifyEqual(t,e.owner_id,"attacked");
    verifyEqual(t,e.event_type,"fragmentation");
    verifyEqual(t,e.nominal_replacement_cost,e.deployment_cost_per_satellite);
    verifyEqual(t,e.market_revenue_per_satellite_year, ...
        r.scenario.econ_params.intercept-r.scenario.econ_params.coef* ...
        sum(r.attack_snapshots{1}.before.owners.Su(:)));
end

function testInvalidCostFileRejected(t)
    [file,folder]=scenario(t); s=opusattack.prepareScenario(file);
    path=fullfile(folder,'case-economics.csv');
    owner_id="missing"; cost_multiplier=1;
    writetable(table(owner_id,cost_multiplier),path);
    verifyError(t,@() opusattack.loadOwnerEconomics(file,s.attack.owners),'OPUS:InvalidOwnerEconomics');
    owner_id="generic"; cost_multiplier=-1;
    writetable(table(owner_id,cost_multiplier),path);
    verifyError(t,@() opusattack.loadOwnerEconomics(file,s.attack.owners),'OPUS:InvalidOwnerEconomics');
    cost_multiplier=1; writetable(table([owner_id;owner_id],[cost_multiplier;cost_multiplier], ...
        'VariableNames',{'owner_id','cost_multiplier'}),path);
    verifyError(t,@() opusattack.loadOwnerEconomics(file,s.attack.owners),'OPUS:InvalidOwnerEconomics');
end
