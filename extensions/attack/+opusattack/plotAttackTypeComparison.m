function report=plotAttackTypeComparison(fragmentationPair,disablingPair,outputFolder)
% Compare one fragmentation and one disabling of the same satellite target.
% Both inputs must be completed attacked/control pairs with identical controls.
    f=readPlotPair(fragmentationPair);
    d=readPlotPair(disablingPair);
    if height(f.fragmentations)~=1 || ~isempty(f.disablings) || ...
            height(d.disablings)~=1 || ~isempty(d.fragmentations)
        error('OPUS:UnmatchedAttackTypes', ...
            'Use one fragmentation-only pair and one disabling-only pair.');
    end
    a=f.fragmentations(1,:); b=d.disablings(1,:);
    if a.time_year~=b.time_year || a.owner_id~=b.owner_id || ...
            a.shell~=b.shell || a.population~=b.population || ...
            a.requested_count~=1 || b.requested_count~=1 || ...
            f.metadata.years~=d.metadata.years
        error('OPUS:UnmatchedAttackTypes', ...
            'Both attacks must affect one satellite of the same owner, shell, population and time, over the same horizon.');
    end
    ownerColumns={'time','shell','owner_id','S','Su','D','sample_index'};
    shellColumns={'time','shell','S','Su','D','N','sample_index'};
    if ~isequaln(f.controlOwners(:,ownerColumns),d.controlOwners(:,ownerColumns)) || ...
            ~isequaln(f.controlShells(:,shellColumns),d.controlShells(:,shellColumns)) || ...
            ~isequaln(f.controlEconomics,d.controlEconomics)
        error('OPUS:UnmatchedAttackControls', ...
            'The no-attack controls differ; use the same initial owners, parameters and launch rules.');
    end
    ids=string(f.impact.owner_id);
    if ~isequal(sort(ids),sort(string(d.impact.owner_id)))
        error('OPUS:UnmatchedAttackControls','The owner sets differ.');
    end
    fragmented=f.impact.delta_discounted_cash_flow_proxy/1e6;
    disabled=zeros(numel(ids),1);
    for i=1:numel(ids)
        hit=d.impact.owner_id==ids(i);
        disabled(i)=d.impact.delta_discounted_cash_flow_proxy(hit)/1e6;
    end
    difference=fragmented-disabled;
    target=ids==a.owner_id;
    summary=table(ids,fragmented,disabled,difference,target, ...
        'VariableNames',{'owner_id','fragmentation_delta_usd_million', ...
        'disabling_delta_usd_million','fragmentation_minus_disabling_usd_million', ...
        'targeted'});
    if nargin<3 || isempty(outputFolder)
        extensionRoot=fileparts(fileparts(mfilename('fullpath')));
        token=char(java.util.UUID.randomUUID());
        outputFolder=fullfile(extensionRoot,'results', ...
            ['attack-type-comparison_' datestr(now,'yyyymmdd_HHMMSS') '_' token(1:8)]);
    end
    outputFolder=char(string(outputFolder));
    if isfolder(outputFolder) || isfile(outputFolder)
        error('OPUS:PlotOutputExists','Figure output already exists: %s',outputFolder);
    end
    [ok,message]=mkdir(outputFolder);
    if ~ok, error('OPUS:PlotExportFailed','%s',message); end
    writetable(summary,fullfile(outputFolder,'attack-type-comparison.csv'));
    style=plotAppearance();
    scale=max(abs([fragmented;disabled]));
    if scale<0.01, scale=0.01; end
    names=strings(0,1);
    for first=1:10:numel(ids)
        last=min(first+9,numel(ids));
        selected=(first:last)';
        figureHeight=max(8,0.62*numel(selected)+3.5);
        fig=figure('Visible','off','Color','white','Units','centimeters', ...
            'Position',[2 2 19 figureHeight],'Renderer','painters');
        ax=axes(fig,'Position',[0.27 0.18 0.68 0.65]);
        set(ax,'FontName',style.font,'FontSize',style.fontSize, ...
            'XColor',style.dark,'YColor',style.dark,'Color',style.paper, ...
            'TickDir','out','Box','off','LineWidth',0.7);
        hold(ax,'on');
        xline(ax,0,'-','Color',style.light,'LineWidth',0.8);
        y=(1:numel(selected))';
        for j=1:numel(selected)
            k=selected(j);
            plot(ax,[fragmented(k),disabled(k)],[y(j)-0.11,y(j)+0.11], ...
                '-','Color',style.light,'LineWidth',0.8,'HandleVisibility','off');
        end
        hF=scatter(ax,fragmented(selected),y-0.11,34,style.orange, ...
            'filled','Marker','o');
        hD=scatter(ax,disabled(selected),y+0.11,34,style.blue, ...
            'filled','Marker','s');
        ax.YDir='reverse';
        ax.YTick=y;
        labels=ids(selected);
        long=strlength(labels)>22;
        labels(long)=extractBefore(labels(long),20)+"...";
        labels(target(selected))=labels(target(selected))+" (target)";
        ax.YTickLabel=cellstr(labels);
        ylim(ax,[0.35 numel(selected)+0.65]);
        xlim(ax,[-1.15*scale 1.15*scale]);
        title(ax,sprintf('Fragmentation versus disabling: shell %d, year %g', ...
            a.shell,a.time_year),'FontWeight','normal');
        xlabel(ax,'Attacked minus no-attack control (discounted USD million)');
        legend(ax,[hF hD],{'Fragmentation','Disabling'}, ...
            'Location','northoutside','Orientation','horizontal','Box','off');
        stem=sprintf('10-fragmentation-vs-disabling-%02d',ceil(first/10));
        exportPaperFigure(fig,outputFolder,stem);
        names(end+1,1)=string(stem); %#ok<AGROW>
    end
    fid=fopen(fullfile(outputFolder,'FIGURE_CAPTIONS.md'),'w','n','UTF-8');
    if fid<0, error('OPUS:PlotExportFailed','Cannot write comparison caption.'); end
    fprintf(fid,'# Matched attack-type comparison\n\n');
    fprintf(fid,'One satellite of %s in shell %d (%s) was attacked at year %g. ', ...
        char(a.owner_id),a.shell,char(a.population),a.time_year);
    fprintf(fid,'Both simulations run for %g years and have identical no-attack controls. ', ...
        f.metadata.years);
    fprintf(fid,'Orange circles are fragmentation; blue squares are disabling. ');
    fprintf(fid,'Each value is the owner''s discounted cash-flow proxy difference ');
    fprintf(fid,'against its own no-attack control, in USD million. ');
    fprintf(fid,'The comparison does not add replacement-value references or service-loss costs.\n\n');
    fprintf(fid,'Fragmentation pair: %s\n\nDisabling pair: %s\n', ...
        f.folder,d.folder);
    fclose(fid);
    marker=fopen(fullfile(outputFolder,'COMPLETE.txt'),'w','n','UTF-8');
    if marker<0, error('OPUS:PlotExportFailed','Cannot write completion marker.'); end
    fprintf(marker,'Matched attack-type comparison exported successfully.\n');
    fclose(marker);
    report=struct('output_directory',outputFolder,'figures',names,'summary',summary);
end
