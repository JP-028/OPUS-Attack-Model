function exportResults(result,folder)
% Export an immutable run directory. Never overwrite an earlier run.
    if isfolder(folder) || isfile(folder)
        error('OPUS:OutputAlreadyExists','Choose a new output directory: %s',folder);
    end
    [ok,message]=mkdir(folder);
    if ~ok, error('OPUS:ExportFailed','%s',message); end
    save(fullfile(folder,'result.mat'),'result','-v7.3');
    h=result.history; nt=numel(h.T); n=size(h.S,2); m=numel(h.owners.ids);
    [ti,ki,oi]=ndgrid(1:nt,1:n,1:m);
    ids=string(h.owners.ids);
    ownerHistory=table(h.T(ti(:)),ki(:),reshape(ids(oi(:)),[],1), ...
        h.owners.S(:),h.owners.Su(:),h.owners.D(:), ...
        'VariableNames',{'time','shell','owner_id','S','Su','D'});
    ownerHistory.sample_index=ti(:);
    ownerHistory.phase=h.phase(ti(:));
    ownerHistory.event_id=h.event_id(ti(:));
    [ti,ki]=ndgrid(1:nt,1:n);
    totals=table(h.T(ti(:)),ki(:),h.S(:),h.Su(:),h.D(:),h.N(:),h.total(:), ...
        'VariableNames',{'time','shell','S','Su','D','N','total'});
    totals.sample_index=ti(:);
    totals.phase=h.phase(ti(:));
    totals.event_id=h.event_id(ti(:));
    writetable(ownerHistory,fullfile(folder,'owner-populations.csv'));
    writetable(totals,fullfile(folder,'shell-populations.csv'));
    fields={'launch_decisions','flows','events','event_participants','source_manifest','fragmentations','population_balance'};
    for i=1:numel(fields)
        name=fields{i}; writetable(result.(name),fullfile(folder,[strrep(name,'_','-') '.csv']));
    end
    diagnostics=table((1:numel(result.intervals))', ...
        cellfun(@(o)o.max_balance_residual,result.intervals), ...
        'VariableNames',{'interval','max_population_balance_residual'});
    writetable(diagnostics,fullfile(folder,'diagnostics.csv'));
    writeText(fullfile(folder,'metadata.json'),jsonencode(result.metadata,'PrettyPrint',true));
    for i=1:numel(result.input_files)
        input=result.input_files(i);
        destination=fullfile(folder,'inputs',input.snapshot_name);
        if ~isfolder(fileparts(destination)), mkdir(fileparts(destination)); end
        writeText(destination,input.contents);
    end
    writeText(fullfile(folder,'COMPLETE.txt'),'Export finished successfully.');
end

function writeText(file,contents)
    fid=fopen(file,'w','n','UTF-8');
    if fid<0, error('OPUS:ExportFailed','Cannot write %s.',file); end
    cleanup=onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid,'%s',contents);
end
