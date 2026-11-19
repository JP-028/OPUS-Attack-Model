function tests=testAttackTypeComparison
    tests=functiontests(localfunctions);
end

function testMatchedSingleSatelliteComparison(t)
    ext=fileparts(fileparts(mfilename('fullpath')));
    t.applyFixture(matlab.unittest.fixtures.PathFixture(ext));
    temporary=t.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
    source=fullfile(ext,'examples','fragmentation');
    kinds=["fragmentation";"disabling"];
    pairFolders=strings(2,1);
    for i=1:2
        kind=char(kinds(i));
        folder=fullfile(temporary.Folder,kind);
        ownerFolder=fullfile(folder,[kind '-owners']);
        mkdir(ownerFolder);
        copyfile(fullfile(source,'fragmentation.csv'), ...
            fullfile(folder,[kind '.csv']));
        copyfile(fullfile(source,'fragmentation-launches.csv'), ...
            fullfile(folder,[kind '-launches.csv']));
        copyfile(fullfile(source,'fragmentation-owners','*.csv'),ownerFolder);
        fid=fopen(fullfile(folder,[kind '-events.csv']),'w');
        assert(fid>=0);
        fprintf(fid,'event_id,time_year,event_type,owner_id,shell,population,count\n');
        fprintf(fid,'matched-001,0.5,%s,attacked,10,S,1\n',kind);
        fclose(fid);
        pair=opusattack.runPairedScenarios(fullfile(folder,[kind '.csv']),1, ...
            fullfile(folder,'pair'));
        pairFolders(i)=string(pair.output_directory);
    end
    for i=1:2
        figures=opusattack.plotPairedResults(pairFolders(i), ...
            fullfile(temporary.Folder,char(kinds(i)+"-figures")));
        verifyTrue(t,isfile(fullfile(figures.output_directory, ...
            '08-economic-by-shell-attacked.pdf')));
    end
    report=opusattack.plotAttackTypeComparison(pairFolders(1),pairFolders(2), ...
        fullfile(temporary.Folder,'comparison'));
    verifyTrue(t,isfile(fullfile(report.output_directory,'COMPLETE.txt')));
    verifyTrue(t,isfile(fullfile(report.output_directory, ...
        '10-fragmentation-vs-disabling-01.pdf')));
    verifyTrue(t,isfile(fullfile(report.output_directory,'attack-type-comparison.csv')));
    row=report.summary(report.summary.owner_id=="attacked",:);
    verifyEqual(t,height(row),1);
    verifyTrue(t,row.targeted);
    verifyEqual(t,row.fragmentation_minus_disabling_usd_million, ...
        row.fragmentation_delta_usd_million-row.disabling_delta_usd_million, ...
        'AbsTol',1e-12);
    verifyError(t,@() opusattack.plotAttackTypeComparison( ...
        pairFolders(2),pairFolders(1),fullfile(temporary.Folder,'reversed')), ...
        'OPUS:UnmatchedAttackTypes');
end
