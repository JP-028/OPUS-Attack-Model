function data=readPlotPair(folder)
% Read only completed paired CSV exports; plotting never reruns the model.
    folder=char(string(folder));
    if ~isfolder(folder) || ~isfile(fullfile(folder,'COMPLETE.txt'))
        error('OPUS:IncompletePlotPair','Expected a completed paired run: %s',folder);
    end
    for child={'attacked','control'}
        if ~isfile(fullfile(folder,child{1},'COMPLETE.txt'))
            error('OPUS:IncompletePlotPair','Missing completed %s run in %s.',child{1},folder);
        end
    end
    data.folder=folder;
    data.metadata=jsondecode(fileread(fullfile(folder,'metadata.json')));
    data.impact=readtable(fullfile(folder,'owner-impact.csv'),'TextType','string');
    data.attackedOwners=readtable(fullfile(folder,'attacked','owner-populations.csv'),'TextType','string');
    data.controlOwners=readtable(fullfile(folder,'control','owner-populations.csv'),'TextType','string');
    data.attackedShells=readtable(fullfile(folder,'attacked','shell-populations.csv'),'TextType','string');
    data.controlShells=readtable(fullfile(folder,'control','shell-populations.csv'),'TextType','string');
    data.attackedEconomics=readtable(fullfile(folder,'attacked','owner-economics.csv'),'TextType','string');
    data.controlEconomics=readtable(fullfile(folder,'control','owner-economics.csv'),'TextType','string');
    data.fragmentations=readtable(fullfile(folder,'attacked','fragmentations.csv'),'TextType','string');
    data.disablings=readtable(fullfile(folder,'attacked','disablings.csv'),'TextType','string');
    eventTime=[data.fragmentations.time_year;data.disablings.time_year];
    eventOwner=[data.fragmentations.owner_id;data.disablings.owner_id];
    eventType=[repmat("F",height(data.fragmentations),1);repmat("D",height(data.disablings),1)];
    data.events=table(eventTime,string(eventOwner),eventType, ...
        'VariableNames',{'time','owner','type'});
    if isempty(data.events)
        error('OPUS:MissingPlotEvents','The attacked run has no applied attacks.');
    end
    data.targetOwners=unique(data.events.owner,'stable');
end
