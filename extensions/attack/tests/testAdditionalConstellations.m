function tests=testAdditionalConstellations
    tests=functiontests(localfunctions);
end

function setupOnce(t)
    ext=fileparts(fileparts(mfilename('fullpath')));
    root=fileparts(fileparts(ext));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(ext));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(fullfile(root,'MOCAT4S')));
    t.TestData.ext=ext;
    t.TestData.file=fullfile(ext,'examples','additional-constellations','additional-constellations.csv');
    t.TestData.run=opusattack.runScenario(t.TestData.file,1,'');
end

function [file,folder,V]=fixture(t,count)
    folder=tempname; mkdir(folder); t.addTeardown(@() rmdir(folder,'s'));
    file=fullfile(folder,'case.csv'); ownerFolder=fullfile(folder,'case-owners'); mkdir(ownerFolder);
    V=struct('N_shell',2,'x0',[10;20;3;4;100;200;5;6]);
    for i=1:count
        shell=[1;2]; S=[i;2*i]; Su=[0;i]; D=[i;0];
        writetable(table(shell,S,Su,D),fullfile(ownerFolder,sprintf('owner-%d.csv',i)));
    end
end

function testAnyOwnerCountAndBackgroundAddedExactlyOnce(t)
    for count=[0,1,3,5]
        [file,~,V]=fixture(t,count);
        [o,x]=opusattack.loadOwners(file,V,V.x0,'additional');
        verifyEqual(t,numel(o.ids),count+1);
        g=find(strcmp(o.ids,'generic'));
        verifyEqual(t,o.S(:,g),V.x0(1:2));
        verifyEqual(t,o.D(:,g),V.x0(3:4));
        verifyEqual(t,o.Su(:,g),V.x0(7:8));
        total=count*(count+1)/2;
        verifyEqual(t,x,V.x0+[total;2*total;total;0;0;0;0;total]);
    end
end

function testReservedGenericAndInvalidModesRejected(t)
    [file,folder,V]=fixture(t,1);
    copyfile(fullfile(folder,'case-owners','owner-1.csv'),fullfile(folder,'case-owners','GENERIC.csv'));
    verifyError(t,@() opusattack.loadOwners(file,V,V.x0,'additional'),'OPUS:ReservedGenericOwner');
    verifyError(t,@() opusattack.loadOwners(file,V,V.x0,'unknown'),'OPUS:InvalidOwnerPopulationMode');
end

function testAdditionalInputsRemainValidated(t)
    [file,folder,V]=fixture(t,1);
    path=fullfile(folder,'case-owners','owner-1.csv'); data=readtable(path);
    data.S(1)=-1; writetable(data,path);
    verifyError(t,@() opusattack.loadOwners(file,V,V.x0,'additional'),'OPUS:InvalidOwnerCounts');
    data.S(1)=1; data.shell(2)=1; writetable(data,path);
    verifyError(t,@() opusattack.loadOwners(file,V,V.x0,'additional'),'OPUS:InvalidOwnerShells');
    verifyError(t,@() opusattack.loadOwners(fullfile(folder,'missing.csv'),V,V.x0,'additional'),'OPUS:MissingOwnerFiles');
end

function testSwitchValidationAndDisabledCompatibility(t)
    [file,~,~]=fixture(t,0);
    parameter_type=["attack";"attack"]; parameter_name=["enabled";"additional_constellations"];
    for value=[-1,0.5,2,NaN]
        parameter_value=[1;value]; writetable(table(parameter_type,parameter_name,parameter_value),file);
        verifyError(t,@() opusattack.prepareScenario(file),'OPUS:InvalidAttackConfiguration');
    end
    parameter_value=[0;1]; writetable(table(parameter_type,parameter_name,parameter_value),file);
    disabled=opusattack.prepareScenario(file); baseline=opusattack.prepareScenario('benchmark');
    verifyEqual(t,disabled.VAR.x0,baseline.VAR.x0);
    verifyEqual(t,disabled.name,baseline.name);
    verifyFalse(t,isfield(disabled.attack,'owners'));
    parameter_value=[1;0]; writetable(table(parameter_type,parameter_name,parameter_value),file);
    verifyError(t,@() opusattack.prepareScenario(file),'OPUS:MissingOwnerFiles');
end

function testTwoConstellationsPreparationAndCommonPolicies(t)
    s=t.TestData.run.scenario; baseline=opusattack.prepareScenario('benchmark');
    o=s.attack.owners; g=find(strcmp(o.ids,'generic')); n=s.VAR.N_shell;
    verifyEqual(t,o.ids,{'generic','kuiper-gen1','starlink-gen1'});
    verifyEqual(t,sum(o.S(:,2:end),1),[3232,4408]);
    verifyEqual(t,o.S(12,2),2076);
    verifyEqual(t,o.S(13,2),1156);
    verifyEqual(t,o.S(10,3),1584);
    verifyEqual(t,o.S(11,3),2824);
    verifyEqual(t,o.S(:,g),baseline.VAR.x0(1:n));
    verifyEqual(t,o.D(:,g),baseline.VAR.x0(n+1:2*n));
    verifyEqual(t,o.Su(:,g),baseline.VAR.x0(3*n+1:4*n));
    verifyEqual(t,s.VAR.x0,[sum(o.S,2);sum(o.D,2);baseline.VAR.x0(2*n+1:3*n);sum(o.Su,2)]);
    verifyEqual(t,sum(s.VAR.x0)-sum(baseline.VAR.x0),7640);
    verifyEmpty(t,s.attack.launch_rules);
    verifyEqual(t,s.attack.owner_economics.cost_multiplier,ones(3,1));
    d=t.TestData.run.launch_decisions;
    verifyTrue(t,all(strcmp(d.mode,'replacement')));
    verifyEqual(t,d.launch_rate,d.current_count/t.TestData.run.parameters.Dt,'AbsTol',1e-10);
    verifyEmpty(t,t.TestData.run.economic_decisions);
    verifyFalse(t,isempty(t.TestData.run.owner_economics));
end

function testAttacksAndFlowsRemainOwnerSpecific(t)
    r=t.TestData.run;
    verifyEqual(t,r.fragmentations.owner_id,["starlink-gen1";"kuiper-gen1"]);
    verifyEqual(t,r.fragmentations.debris_added,[348.4375;348.4375]);
    verifyEqual(t,r.disablings.owner_id,["starlink-gen1";"kuiper-gen1"]);
    verifyEqual(t,r.disablings.disabled_count,[1;1]);
    for i=1:4
        snapshot=r.attack_snapshots{i}; before=snapshot.before; after=snapshot.after;
        event=r.scenario.attack.events(i,:);
        target=char(event.owner_id); shell=event.shell;
        j=find(strcmp(before.owners.ids,target)); untouched=setdiff(1:3,j);
        for pop={'S','Su','D'}
            verifyEqual(t,after.owners.(pop{1})(:,untouched),before.owners.(pop{1})(:,untouched));
        end
        verifyEqual(t,after.owners.S(shell,j),before.owners.S(shell,j)-1,'AbsTol',1e-10);
        if event.event_type=="fragmentation"
            verifyEqual(t,after.N(shell)-before.N(shell),348.4375,'AbsTol',1e-9);
        else
            verifyEqual(t,after.owners.D(shell,j)-before.owners.D(shell,j),1,'AbsTol',1e-9);
        end
    end
    verifyLessThan(t,r.max_global_balance_residual,1e-5);
    verifyEqual(t,sort(unique(string(r.launch_decisions.owner_id))),["generic";"kuiper-gen1";"starlink-gen1"]);
    for pop={'S','Su','D'}
        verifyEqual(t,sum(r.history.owners.(pop{1}),3),r.history.(pop{1}),'AbsTol',1e-10);
    end
end

function testCombinedDynamicsMatchOriginalWithSameLaunches(t)
    r=t.TestData.run; V=r.parameters; n=V.N_shell; x=V.x0;
    old=warning; cleanup=onCleanup(@() warning(old)); %#ok<NASGU>
    for i=1:numel(r.intervals)
        out=r.intervals{i};
        hits=find(r.scenario.attack.events.time_year==out.T(1));
        for row=hits'
            e=r.scenario.attack.events(row,:); x(e.shell)=x(e.shell)-e.count;
            if e.event_type=="fragmentation"
                x(2*n+e.shell)=x(2*n+e.shell)+V.mass(1)/V.mass(3);
            else
                x(n+e.shell)=x(n+e.shell)+e.count;
            end
        end
        ref=MOCAT4S(out.T,x,[sum(out.launches.S,2),sum(out.launches.Su,2)],V);
        for pop={'S','D','N','Su'}
            a=out.(pop{1}); b=ref.(pop{1});
            verifyLessThan(t,max(abs(a(:)-b(:))./max(1,abs(b(:)))),3e-6);
        end
        x=[ref.S(end,:)';ref.D(end,:)';ref.N(end,:)';ref.Su(end,:)'];
    end
end

function testExportIncludesGenericAndReproducibleInputs(t)
    folder=tempname; t.addTeardown(@() rmdir(folder,'s'));
    r=t.TestData.run; opusattack.exportResults(r,folder);
    data=readtable(fullfile(folder,'owner-populations.csv'),'TextType','string');
    verifyEqual(t,sort(unique(data.owner_id)),["generic";"kuiper-gen1";"starlink-gen1"]);
    meta=jsondecode(fileread(fullfile(folder,'metadata.json')));
    verifyEqual(t,meta.initial_population_mode,'additional_constellations');
    verifyEqual(t,meta.generic_owner_id,'generic');
    verifyTrue(t,isfile(fullfile(folder,'inputs','owners','starlink-gen1.csv')));
    verifyTrue(t,isfile(fullfile(folder,'inputs','owners','kuiper-gen1.csv')));
    saved=load(fullfile(folder,'result.mat'),'result');
    verifyEqual(t,saved.result.scenario.VAR.x0,r.scenario.VAR.x0);
    verifyTrue(t,isfile(fullfile(folder,'COMPLETE.txt')));
end
