function report=plotOwnerComparison(pairFolders,outputFolder)
% Compare all owners' discounted economic effects across completed pairs.
% At most ten owner rows per panel and three panels per page prevent crowding.
    if nargin<1 || isempty(pairFolders)
        error('OPUS:MissingPlotPair','Supply one or more paired result folders.');
    end
    folders=string(pairFolders(:));
    if any(strlength(folders)==0)
        error('OPUS:MissingPlotPair','Pair folder paths must not be empty.');
    end
    if nargin<2 || isempty(outputFolder)
        extensionRoot=fileparts(fileparts(mfilename('fullpath')));
        token=char(java.util.UUID.randomUUID());
        outputFolder=fullfile(extensionRoot,'results', ...
            ['owner-comparison_' datestr(now,'yyyymmdd_HHMMSS') '_' token(1:8)]);
    end
    outputFolder=char(string(outputFolder));
    if isfolder(outputFolder) || isfile(outputFolder)
        error('OPUS:PlotOutputExists','Figure output already exists: %s',outputFolder);
    end
    style=plotAppearance();
    panels=struct('pair',{},'label',{},'rows',{});
    allValues=[];
    allNormalized=[];
    summary=table('Size',[0,6], ...
        'VariableTypes',{'double','string','string','double','double','logical'}, ...
        'VariableNames',{'pair_number','targeted_owners','owner_id', ...
        'delta_discounted_cash_flow_proxy','per_1000_initial_active','targeted'});
    for i=1:numel(folders)
        folder=char(folders(i));
        if ~isfile(fullfile(folder,'COMPLETE.txt'))
            error('OPUS:IncompletePlotPair','Expected a completed pair: %s',folder);
        end
        impact=readtable(fullfile(folder,'owner-impact.csv'),'TextType','string');
        if ~all(ismember({'owner_id','initial_active','delta_discounted_cash_flow_proxy', ...
                'fragmented','disabled'},impact.Properties.VariableNames))
            error('OPUS:InvalidPlotSeries','Owner impact columns are missing in %s.',folder);
        end
        targeted=impact.fragmented+impact.disabled>0;
        targetNames=impact.owner_id(targeted);
        if isempty(targetNames)
            error('OPUS:MissingPlotEvents','Pair has no targeted owner: %s.',folder);
        end
        label=strjoin(targetNames,', ');
        if strlength(label)>34
            label=string(numel(targetNames))+" targeted owners";
        end
        allValues=[allValues;impact.delta_discounted_cash_flow_proxy(:)/1e6]; %#ok<AGROW>
        normalized=NaN(height(impact),1);
        valid=impact.initial_active>0;
        normalized(valid)=impact.delta_discounted_cash_flow_proxy(valid) ...
            ./impact.initial_active(valid)*1000/1e6;
        allNormalized=[allNormalized;normalized]; %#ok<AGROW>
        for k=1:height(impact)
            summary(end+1,:)={i,label,impact.owner_id(k), ...
                impact.delta_discounted_cash_flow_proxy(k),normalized(k),targeted(k)}; %#ok<AGROW>
        end
        for startRow=1:10:height(impact)
            lastRow=min(startRow+9,height(impact));
            suffix="";
            if height(impact)>10
                suffix=sprintf(' (owners %d-%d of %d)',startRow,lastRow,height(impact));
            end
            panels(end+1)=struct('pair',i, ...
                'label',"Attack on "+label+suffix, ...
                'rows',impact(startRow:lastRow,:)); %#ok<AGROW>
        end
    end
    [ok,message]=mkdir(outputFolder);
    if ~ok, error('OPUS:PlotExportFailed','%s',message); end
    writetable(summary,fullfile(outputFolder,'owner-comparison-data.csv'));
    finiteNormalized=allNormalized(isfinite(allNormalized));
    if isempty(finiteNormalized), finiteNormalized=0; end
    scales=[max(abs(allValues)),max(abs(finiteNormalized))];
    scales(~isfinite(scales) | scales<0.01)=0.01;
    names=strings(0,1);
    for metric=1:2
        scale=scales(metric);
        for first=1:3:numel(panels)
            last=min(first+2,numel(panels));
            group=panels(first:last);
            rowsOnPage=arrayfun(@(p)height(p.rows),group);
            panelHeight=max(4.0,0.55*max(rowsOnPage)+1.4);
            figureHeight=1.8+panelHeight*numel(group);
            f=figure('Visible','off','Color','white','Units','centimeters', ...
                'Position',[2 2 18 figureHeight],'Renderer','painters');
            layout=tiledlayout(f,numel(group),1,'Padding','loose','TileSpacing','loose');
            for j=1:numel(group)
                ax=nexttile(layout);
                set(ax,'FontName',style.font,'FontSize',style.fontSize, ...
                    'XColor',style.dark,'YColor',style.dark,'Color',style.paper, ...
                    'TickDir','out','Box','off','LineWidth',0.7);
                hold(ax,'on');
                rows=group(j).rows;
                if metric==1
                    value=rows.delta_discounted_cash_flow_proxy/1e6;
                else
                    value=NaN(height(rows),1);
                    valid=rows.initial_active>0;
                    value(valid)=rows.delta_discounted_cash_flow_proxy(valid) ...
                        ./rows.initial_active(valid)*1000/1e6;
                end
                colors=repmat(style.blue,height(rows),1);
                colors(rows.owner_id=="generic",:)=repmat(style.grey,sum(rows.owner_id=="generic"),1);
                target=rows.fragmented+rows.disabled>0;
                colors(target,:)=repmat(style.orange,sum(target),1);
                xline(ax,0,'-','Color',style.light,'LineWidth',0.8);
                scatter(ax,value,(1:height(rows))',32,colors,'filled');
                ax.YDir='reverse';
                ax.YTick=1:height(rows);
                labels=string(rows.owner_id);
                long=strlength(labels)>22;
                labels(long)=extractBefore(labels(long),20)+"...";
                if metric==2
                    labels(~isfinite(value))=labels(~isfinite(value))+" (n/a)";
                end
                ax.YTickLabel=cellstr(labels);
                ylim(ax,[0.4 height(rows)+0.6]);
                xlim(ax,[-1.12*scale 1.12*scale]);
                title(ax,group(j).label,'Interpreter','none','FontWeight','normal');
                if metric==1
                    xlabel(ax,'Attacked minus control (USD million)');
                else
                    xlabel(ax,'Difference (USD million per 1,000 initial satellites)');
                end
            end
            page=(first+2)/3;
            if metric==1
                stem=sprintf('05-owner-comparison-%02d',ceil(page));
            else
                stem=sprintf('07-owner-comparison-normalized-%02d',ceil(page));
            end
            exportPaperFigure(f,outputFolder,stem);
            names(end+1,1)=string(stem); %#ok<AGROW>
        end
    end
    fid=fopen(fullfile(outputFolder,'FIGURE_CAPTIONS.md'),'w','n','UTF-8');
    if fid<0, error('OPUS:PlotExportFailed','Cannot write comparison caption.'); end
    fprintf(fid,'# Owner comparison\n\n');
    fprintf(fid,'Each panel is one attacked/no-attack paired experiment. ');
    fprintf(fid,'The horizontal position is the final difference in modeled discounted ');
    fprintf(fid,'cash-flow proxy, in USD million (attacked minus control). ');
    fprintf(fid,'Orange identifies an owner targeted in that pair; blue marks other named ');
    fprintf(fid,'owners; grey marks generic. All pages use the same horizontal scale. ');
    fprintf(fid,'These are OPUS-based model outcomes, not company profits. ');
    fprintf(fid,'Owners are split into additional panels after ten rows to keep labels legible.\n');
    fprintf(fid,'Figure 07 divides each owner''s discounted cash-flow difference by its ');
    fprintf(fid,'initial active count and multiplies by 1,000. Its unit is USD million ');
    fprintf(fid,'per 1,000 initially active satellites. Owners with zero initial active ');
    fprintf(fid,'satellites are marked n/a, and all panels share one normalized scale. ');
    fprintf(fid,'Different attack counts or horizons still limit direct comparisons.\n\n');
    fprintf(fid,'| Pair | Folder |\n| ---: | --- |\n');
    for i=1:numel(folders)
        fprintf(fid,'| %d | %s |\n',i,char(folders(i)));
    end
    fclose(fid);
    marker=fopen(fullfile(outputFolder,'COMPLETE.txt'),'w','n','UTF-8');
    if marker<0, error('OPUS:PlotExportFailed','Cannot write comparison completion marker.'); end
    fprintf(marker,'Owner comparison exported successfully.\n');
    fclose(marker);
    report=struct('output_directory',outputFolder,'figures',names,'summary',summary);
end
