function balance = populationBalance(initial,initialN,final,flows)
% Global balance includes continuous flows AND instantaneous attack transfers.
    n=numel(initialN); m=numel(initial.ids); rows=cell(n*(3*m+1),8); q=0;
    for i=1:m+1
        if i<=m, owner=initial.ids{i}; species={'S','Su','D'};
        else, owner=''; species={'N'}; end
        for type=species
            pop=type{1};
            if strcmp(pop,'N'), before=initialN; after=final.N;
            else, before=initial.(pop)(:,i); after=final.owners.(pop)(:,i); end
            out=strcmp(flows.owner_id,owner) & strcmp(flows.population,pop);
            in=strcmp(flows.destination_owner_id,owner) & strcmp(flows.destination_population,pop);
            for k=1:n
                outgoing=sum(flows.source_count(out & flows.shell==k));
                incoming=sum(flows.destination_count(in & flows.destination_shell==k));
                q=q+1;
                rows(q,:)={owner,pop,k,before(k),after(k),incoming,outgoing,after(k)-before(k)-incoming+outgoing};
            end
        end
    end
    balance=cell2table(rows,'VariableNames',{'owner_id','population','shell','initial_count', ...
        'final_count','incoming','outgoing','residual'});
end
