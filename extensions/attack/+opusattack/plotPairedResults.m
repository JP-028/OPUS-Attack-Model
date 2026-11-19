function report=plotPairedResults(pairFolder,outputFolder)
% Export publication-style figures from a completed attacked/control pair.
% The simulation and its input files are never modified or rerun.
    if nargin<1, error('OPUS:MissingPlotPair','Supply a paired result folder.'); end
    data=readPlotPair(pairFolder);
    if nargin<2 || isempty(outputFolder)
        outputFolder=fullfile(data.folder,'figures');
    end
    outputFolder=char(string(outputFolder));
    if isfolder(outputFolder) || isfile(outputFolder)
        error('OPUS:PlotOutputExists','Figure output already exists: %s',outputFolder);
    end
    [ok,message]=mkdir(outputFolder);
    if ~ok, error('OPUS:PlotExportFailed','%s',message); end
    style=plotAppearance();
    names=strings(0,1); subjects=strings(0,1); descriptions=strings(0,1);
    for i=1:numel(data.targetOwners)
        owner=data.targetOwners(i);
        stem=char(owner);
        f=activeFigure(data,owner,style);
        exportPaperFigure(f,outputFolder,['01-active-fleet-' stem]);
        names(end+1,1)="01-active-fleet-"+owner;
        subjects(end+1,1)=owner;
        descriptions(end+1,1)="Active S+Su and attacked-minus-control difference over time";
        f=economicFigure(data,owner,style);
        exportPaperFigure(f,outputFolder,['03-economic-trajectory-' stem]);
        names(end+1,1)="03-economic-trajectory-"+owner;
        subjects(end+1,1)=owner;
        descriptions(end+1,1)="Cumulative discounted cash-flow proxy difference";
        f=componentsFigure(data,owner,style);
        exportPaperFigure(f,outputFolder,['04-economic-components-' stem]);
        names(end+1,1)="04-economic-components-"+owner;
        subjects(end+1,1)=owner;
        descriptions(end+1,1)="Revenue and spending contributions to cash-flow difference";
        f=economicDevelopmentFigure(data,owner,style);
        exportPaperFigure(f,outputFolder,['06-economic-development-' stem]);
        names(end+1,1)="06-economic-development-"+owner;
        subjects(end+1,1)=owner;
        descriptions(end+1,1)="Annualized revenue and cash-flow proxy, with paired differences";
        shellImpact=economicImpactByShell(data,owner);
        writetable(shellImpact,fullfile(outputFolder,['economic-by-shell-' stem '.csv']));
        f=shellEconomicFigure(shellImpact,owner,data,style);
        exportPaperFigure(f,outputFolder,['08-economic-by-shell-' stem]);
        names(end+1,1)="08-economic-by-shell-"+owner;
        subjects(end+1,1)=owner;
        descriptions(end+1,1)="Discounted revenue, spending and net cash-flow changes by shell";
        f=replacementFigure(data,owner,style);
        exportPaperFigure(f,outputFolder,['09-replacement-reference-' stem]);
        names(end+1,1)="09-replacement-reference-"+owner;
        subjects(end+1,1)=owner;
        descriptions(end+1,1)="Nominal replacement-value reference beside discounted cash-flow difference";
    end
    f=debrisFigure(data,style);
    exportPaperFigure(f,outputFolder,'02-debris-by-altitude');
    names(end+1,1)="02-debris-by-altitude";
    subjects(end+1,1)="all targeted owners";
    descriptions(end+1,1)="Shell-average debris difference over time";
    manifest=table(names,subjects,descriptions, ...
        'VariableNames',{'figure','subject','description'});
    writetable(manifest,fullfile(outputFolder,'figure-manifest.csv'));
    writeCaptions(outputFolder,data);
    fid=fopen(fullfile(outputFolder,'COMPLETE.txt'),'w','n','UTF-8');
    if fid<0, error('OPUS:PlotExportFailed','Cannot write figure completion marker.'); end
    fprintf(fid,'Figure export finished successfully.\n');
    fclose(fid);
    report=struct('output_directory',outputFolder,'manifest',manifest);
end

function f=activeFigure(data,owner,style)
    [ta,ya]=activeSeries(data.attackedOwners,owner);
    [tc,yc]=activeSeries(data.controlOwners,owner);
    baseline=interp1(tc,yc,ta,'linear');
    if any(~isfinite(baseline)), error('OPUS:InvalidPlotSeries','Control fleet times do not cover attack times.'); end
    f=paperFigure(18,12);
    layout=tiledlayout(f,2,1,'Padding','loose','TileSpacing','loose');
    title(layout,'Active fleet: '+owner,'Interpreter','none','FontWeight','normal');
    ax=nexttile(layout);
    decorate(ax,style);
    plotEventRules(ax,data.events,style);
    control=plot(ax,tc,yc,'--','Color',style.grey,'LineWidth',1.35);
    hold(ax,'on');
    attacked=plot(ax,ta,ya,'-','Color',style.orange,'LineWidth',1.65);
    ylabel(ax,'Active S + Su (satellites)');
    xlim(ax,[0 max(ta)]);
    legend(ax,[attacked control],{'Attacked','No attack'}, ...
        'Location','northeastoutside','Box','off');
    ax2=nexttile(layout);
    decorate(ax2,style);
    plotEventRules(ax2,data.events,style);
    yline(ax2,0,'-','Color',style.light,'LineWidth',0.8,'HandleVisibility','off');
    plot(ax2,ta,ya-baseline,'-','Color',style.orange,'LineWidth',1.65);
    xlabel(ax2,'Simulation time (years)');
    ylabel(ax2,'Difference (satellites)');
    xlim(ax2,[0 max(ta)]);
end

function f=debrisFigure(data,style)
    [ta,na]=debrisSeries(data.attackedShells);
    [tc,nc]=debrisSeries(data.controlShells);
    baseline=interp1(tc,nc,ta,'linear');
    if any(~isfinite(baseline(:))), error('OPUS:InvalidPlotSeries','Control debris times do not cover attack times.'); end
    delta=na-baseline;
    n=size(delta,2);
    root=fileparts(fileparts(mfilename('fullpath')));
    shells=readtable(fullfile(root,'templates','shell-reference.csv'));
    if height(shells)<n
        error('OPUS:InvalidPlotSeries','The shell reference does not cover all plotted shells.');
    end
    altitude=(shells.lower_altitude_km(1:n)+shells.upper_altitude_km(1:n))/2;
    f=paperFigure(18,10);
    ax=axes(f,'Position',[0.13 0.17 0.67 0.73]);
    decorate(ax,style);
    x=repmat(ta(:)',n,1);
    y=repmat(altitude(:),1,numel(ta));
    surf(ax,x,y,zeros(size(x)),delta','FaceColor','interp','EdgeColor','none');
    view(ax,2);
    colormap(ax,divergingMap(style));
    limit=max(abs(delta(:)));
    if limit<1e-9, limit=1; end
    clim(ax,[-limit limit]);
    colorbarHandle=colorbar(ax,'eastoutside');
    colorbarHandle.Label.String='Change in N (objects)';
    colorbarHandle.FontName=style.font;
    colorbarHandle.FontSize=style.fontSize;
    xlabel(ax,'Simulation time (years)');
    ylabel(ax,'Altitude (km)');
    title(ax,'Debris: attacked minus no attack','FontWeight','normal');
    xlim(ax,[0 max(ta)]);
    strength=max(abs(delta),[],1);
    affected=find(strength>=max(1e-8,0.01*limit));
    targets=[data.fragmentations.shell;data.disablings.shell];
    focus=unique([affected(:);targets(:)]);
    if isempty(focus), focus=(1:n)'; end
    low=max(1,min(focus)-2);
    high=min(n,max(focus)+2);
    ylim(ax,[shells.lower_altitude_km(low),shells.upper_altitude_km(high)]);
    plotEventRules(ax,data.events,style);
end

function f=economicFigure(data,owner,style)
    [ta,mainA]=economicSeries(data.attackedEconomics,owner,true);
    [tc,mainC]=economicSeries(data.controlEconomics,owner,true);
    [to,otherA]=economicSeries(data.attackedEconomics,owner,false);
    [tp,otherC]=economicSeries(data.controlEconomics,owner,false);
    if ~isequal(ta,tc,to,tp)
        error('OPUS:InvalidPlotSeries','Paired economic intervals do not match.');
    end
    f=paperFigure(18,12);
    layout=tiledlayout(f,2,1,'Padding','loose','TileSpacing','loose');
    title(layout,'Discounted cash-flow difference: '+owner, ...
        'Interpreter','none','FontWeight','normal');
    ax=nexttile(layout);
    decorate(ax,style);
    plotEventRules(ax,data.events,style);
    yline(ax,0,'-','Color',style.light,'HandleVisibility','off');
    plot(ax,ta,(mainA-mainC)/1e6,'-o','Color',style.orange, ...
        'MarkerFaceColor',style.orange,'MarkerSize',3.5,'LineWidth',1.5);
    ylabel(ax,'Attacked owner (USD million)');
    xlim(ax,[0 max(ta)]);
    ax2=nexttile(layout);
    decorate(ax2,style);
    plotEventRules(ax2,data.events,style);
    yline(ax2,0,'-','Color',style.light,'HandleVisibility','off');
    plot(ax2,ta,(otherA-otherC)/1e6,'-o','Color',style.blue, ...
        'MarkerFaceColor',style.blue,'MarkerSize',3.5,'LineWidth',1.5);
    ylabel(ax2,'Other owners (USD million)');
    xlabel(ax2,'Simulation time (years)');
    xlim(ax2,[0 max(ta)]);
end

function f=economicDevelopmentFigure(data,owner,style)
    [ta,ra,ca]=ownerEconomicRates(data.attackedEconomics,owner);
    [tc,rc,cc]=ownerEconomicRates(data.controlEconomics,owner);
    if ~isequal(ta,tc)
        error('OPUS:InvalidPlotSeries','Paired economic intervals do not match.');
    end
    f=paperFigure(22,14);
    layout=tiledlayout(f,2,2,'Padding','loose','TileSpacing','loose');
    title(layout,'Economic development: '+owner,'Interpreter','none','FontWeight','normal');
    ax=nexttile(layout,1);
    decorate(ax,style);
    plotEventRules(ax,data.events,style);
    attacked=stairs(ax,ta,[ra;ra(end)],'-','Color',style.orange,'LineWidth',1.55);
    control=stairs(ax,ta,[rc;rc(end)],'--','Color',style.grey,'LineWidth',1.25);
    ylabel(ax,'Revenue (USD million/year)');
    xlim(ax,[ta(1) ta(end)]);
    legend(ax,[attacked control],{'Attacked','No attack'}, ...
        'Location','northwest','Box','off');
    padY(ax,[ra;rc]);
    ax=nexttile(layout,2);
    decorate(ax,style);
    plotEventRules(ax,data.events,style);
    stairs(ax,ta,[ca;ca(end)],'-','Color',style.orange,'LineWidth',1.55);
    stairs(ax,ta,[cc;cc(end)],'--','Color',style.grey,'LineWidth',1.25);
    ylabel(ax,'Cash-flow proxy (USD million/year)');
    padY(ax,[ca;cc]);
    xlim(ax,[ta(1) ta(end)]);
    ax=nexttile(layout,3);
    decorate(ax,style);
    plotEventRules(ax,data.events,style);
    yline(ax,0,'-','Color',style.light,'HandleVisibility','off');
    delta=ra-rc;
    stairs(ax,ta,[delta;delta(end)],'-','Color',style.blue,'LineWidth',1.55);
    ylabel(ax,'Revenue difference (USD million/year)');
    padY(ax,[delta;0]);
    xlabel(ax,'Simulation time (years)');
    xlim(ax,[ta(1) ta(end)]);
    ax=nexttile(layout,4);
    decorate(ax,style);
    plotEventRules(ax,data.events,style);
    yline(ax,0,'-','Color',style.light,'HandleVisibility','off');
    delta=ca-cc;
    stairs(ax,ta,[delta;delta(end)],'-','Color',style.blue,'LineWidth',1.55);
    ylabel(ax,'Cash-flow difference (USD million/year)');
    padY(ax,[delta;0]);
    xlabel(ax,'Simulation time (years)');
    xlim(ax,[ta(1) ta(end)]);
end

function [edges,revenue,cashFlow]=ownerEconomicRates(rows,owner)
    rows=rows(rows.owner_id==owner,:);
    if isempty(rows)
        error('OPUS:InvalidPlotSeries','Owner %s has no economic records.',owner);
    end
    ends=unique(rows.end_time);
    starts=zeros(numel(ends),1);
    revenue=zeros(numel(ends),1);
    cashFlow=zeros(numel(ends),1);
    for j=1:numel(ends)
        segment=rows(rows.end_time==ends(j),:);
        start=unique(segment.start_time);
        if numel(start)~=1 || ends(j)<=start
            error('OPUS:InvalidPlotSeries','Invalid economic interval for %s.',owner);
        end
        starts(j)=start;
        duration=ends(j)-start;
        revenue(j)=sum(segment.modeled_revenue)/duration/1e6;
        cashFlow(j)=sum(segment.cash_flow_proxy)/duration/1e6;
    end
    if any(abs(starts(2:end)-ends(1:end-1))>1e-8)
        error('OPUS:InvalidPlotSeries','Economic intervals are not contiguous for %s.',owner);
    end
    edges=[starts(1);ends];
end
function f=componentsFigure(data,owner,style)
    row=data.impact(data.impact.owner_id==owner,:);
    if height(row)~=1, error('OPUS:InvalidPlotSeries','Expected one impact row for %s.',owner); end
    values=[row.delta_modeled_revenue; -row.delta_launch_spending; ...
        row.delta_cash_flow_proxy]/1e6;
    if abs(values(1)+values(2)-values(3))>1e-6*max(1,max(abs(values)))
        error('OPUS:InvalidPlotSeries','Cash-flow components do not balance.');
    end
    f=paperFigure(18,8);
    ax=axes(f,'Position',[0.32 0.22 0.60 0.65]);
    decorate(ax,style);
    b=barh(ax,1:3,values,0.48,'FaceColor','flat','EdgeColor','none');
    b.CData=[style.blue;style.orange;style.dark];
    ax.YDir='reverse';
    ax.YTick=1:3;
    ax.YTickLabel={'Revenue change','Less: spending change','Net cash-flow change'};
    limit=max(abs(values));
    if limit<0.01, limit=0.01; end
    xlim(ax,[-1.15*limit,1.45*limit]);
    ylim(ax,[0.45 3.55]);
    xline(ax,0,'-','Color',style.grey,'LineWidth',0.8);
    for j=1:3
        text(ax,1.35*limit,j,sprintf('%+.3f',values(j)), ...
            'HorizontalAlignment','right','VerticalAlignment','middle', ...
            'FontName',style.font,'FontSize',style.fontSize,'Color',style.dark);
    end
    title(ax,'Economic components: '+owner,'Interpreter','none','FontWeight','normal');
    xlabel(ax,'Attacked minus control (USD million)');
end

function impact=economicImpactByShell(data,owner)
    a=data.attackedEconomics;
    c=data.controlEconomics;
    a=a(a.owner_id==owner,:);
    c=c(c.owner_id==owner,:);
    n=max([data.attackedShells.shell;data.controlShells.shell]);
    shell=(1:n)';
    revenue=zeros(n,1);
    spending=zeros(n,1);
    net=zeros(n,1);
    for k=1:n
        ar=a(a.shell==k,:); cr=c(c.shell==k,:);
        revenue(k)=(sum(ar.discounted_revenue)-sum(cr.discounted_revenue))/1e6;
        spending(k)=-(sum(ar.discounted_launch_spending)- ...
            sum(cr.discounted_launch_spending))/1e6;
        net(k)=(sum(ar.discounted_cash_flow_proxy)- ...
            sum(cr.discounted_cash_flow_proxy))/1e6;
    end
    if any(abs(revenue+spending-net)>1e-6*max(1,max(abs(net))))
        error('OPUS:InvalidPlotSeries','Shell economic components do not balance for %s.',owner);
    end
    row=data.impact(data.impact.owner_id==owner,:);
    if height(row)~=1 || abs(sum(net)-row.delta_discounted_cash_flow_proxy/1e6)> ...
            1e-6*max(1,abs(row.delta_discounted_cash_flow_proxy/1e6))
        error('OPUS:InvalidPlotSeries','Shell economic totals do not match owner impact for %s.',owner);
    end
    root=fileparts(fileparts(mfilename('fullpath')));
    reference=readtable(fullfile(root,'templates','shell-reference.csv'));
    if height(reference)<n
        error('OPUS:InvalidPlotSeries','Shell reference is shorter than the result.');
    end
    impact=table(shell,reference.lower_altitude_km(1:n), ...
        reference.upper_altitude_km(1:n),revenue,spending,net, ...
        'VariableNames',{'shell','lower_altitude_km','upper_altitude_km', ...
        'delta_discounted_revenue_usd_million', ...
        'less_delta_discounted_spending_usd_million', ...
        'delta_discounted_cash_flow_usd_million'});
end

function f=shellEconomicFigure(impact,owner,data,style)
    values=[impact.delta_discounted_revenue_usd_million, ...
        impact.less_delta_discounted_spending_usd_million, ...
        impact.delta_discounted_cash_flow_usd_million];
    score=max(abs(values),[],2);
    [~,rank]=sort(score,'descend');
    threshold=max(1e-6,0.01*max(score));
    material=rank(score(rank)>=threshold);
    selected=material(1:min(8,numel(material)));
    targetShells=unique([ ...
        data.fragmentations.shell(data.fragmentations.owner_id==owner); ...
        data.disablings.shell(data.disablings.owner_id==owner)]);
    context=unique([targetShells-1;targetShells;targetShells+1]);
    context=context(context>=1 & context<=height(impact));
    selected=sort(unique([selected;context]));
    plotted=values(selected,:);
    maxValue=max(abs(plotted(:)));
    if maxValue<0.001, maxValue=0.001; end
    f=paperFigure(25,max(9,0.58*numel(selected)+4));
    layout=tiledlayout(f,1,3,'Padding','loose','TileSpacing','loose');
    title(layout,'Economic impact by shell: '+owner, ...
        'Interpreter','none','FontWeight','normal');
    captions={'Revenue change','Less: spending change','Net cash-flow change'};
    colors=[style.blue;style.orange;style.dark];
    for j=1:3
        ax=nexttile(layout);
        decorate(ax,style);
        barh(ax,1:numel(selected),plotted(:,j),0.58, ...
            'FaceColor',colors(j,:),'EdgeColor','none');
        xline(ax,0,'-','Color',style.grey,'LineWidth',0.8);
        ax.YDir='reverse';
        ax.YTick=1:numel(selected);
        if j==1
            labels=compose('%d: %g-%g km',impact.shell(selected), ...
                impact.lower_altitude_km(selected),impact.upper_altitude_km(selected));
            ax.YTickLabel=cellstr(labels);
        else
            ax.YTickLabel={};
        end
        ylim(ax,[0.4 numel(selected)+0.6]);
        xlim(ax,[-1.12*maxValue 1.12*maxValue]);
        title(ax,captions{j},'FontWeight','normal');
        xlabel(ax,'Discounted USD million');
    end
end

function f=replacementFigure(data,owner,style)
    attack=data.attackEconomics(data.attackEconomics.owner_id==owner,:);
    if isempty(attack)
        error('OPUS:InvalidPlotSeries','Attack valuation is missing for %s.',owner);
    end
    reference=sum(attack.nominal_replacement_cost)/1e6;
    row=data.impact(data.impact.owner_id==owner,:);
    if height(row)~=1
        error('OPUS:InvalidPlotSeries','Expected one economic impact row for %s.',owner);
    end
    cash=row.delta_discounted_cash_flow_proxy/1e6;
    f=paperFigure(19,8);
    layout=tiledlayout(f,1,2,'Padding','loose','TileSpacing','loose');
    title(layout,'Two economic measures: '+owner, ...
        'Interpreter','none','FontWeight','normal');
    ax=nexttile(layout);
    decorate(ax,style);
    barh(ax,1,reference,0.45,'FaceColor',style.orange,'EdgeColor','none');
    ax.YTick=[];
    ylim(ax,[0.5 1.5]);
    xlim(ax,[0 max(0.01,1.15*reference)]);
    title(ax,'Replacement-value reference','FontWeight','normal');
    xlabel(ax,'Nominal USD million');
    ax=nexttile(layout);
    decorate(ax,style);
    barh(ax,1,cash,0.45,'FaceColor',style.blue,'EdgeColor','none');
    xline(ax,0,'-','Color',style.grey,'LineWidth',0.8);
    ax.YTick=[];
    ylim(ax,[0.5 1.5]);
    limit=max(0.01,abs(cash));
    xlim(ax,[-1.15*limit 1.15*limit]);
    title(ax,'Attacked minus control cash flow','FontWeight','normal');
    xlabel(ax,'Discounted USD million');
end
function [time,value]=activeSeries(rows,owner)
    hit=rows.owner_id==owner;
    if ~any(hit), error('OPUS:InvalidPlotSeries','Owner %s is missing from population history.',owner); end
    index=rows.sample_index(hit);
    count=max(rows.sample_index);
    time=accumarray(index,rows.time(hit),[count,1],@min);
    value=accumarray(index,rows.S(hit)+rows.Su(hit),[count,1],@sum);
    if any(diff(time)<0), error('OPUS:InvalidPlotSeries','Population times are not ordered.'); end
end

function [time,value]=debrisSeries(rows)
    count=max(rows.sample_index);
    shells=max(rows.shell);
    time=accumarray(rows.sample_index,rows.time,[count,1],@min);
    value=accumarray([rows.sample_index,rows.shell],rows.N,[count,shells],@sum);
    if any(diff(time)<0), error('OPUS:InvalidPlotSeries','Debris times are not ordered.'); end
end

function [time,value]=economicSeries(rows,owner,selectedOwner)
    endTimes=unique(rows.end_time);
    time=[0;endTimes];
    value=zeros(numel(time),1);
    if selectedOwner, mask=rows.owner_id==owner;
    else, mask=rows.owner_id~=owner;
    end
    for j=1:numel(endTimes)
        value(j+1)=value(j)+sum(rows.discounted_cash_flow_proxy( ...
            mask & rows.end_time==endTimes(j)));
    end
end

function padY(ax,values)
    low=min(values(:));
    high=max(values(:));
    span=high-low;
    if span<1e-10, span=max(1,0.05*abs(high)); end
    margin=0.08*span;
    ylim(ax,[low-margin high+margin]);
end
function f=paperFigure(width,height)
    f=figure('Visible','off','Color','white','Units','centimeters', ...
        'Position',[2 2 width height],'Renderer','painters');
end

function decorate(ax,style)
    set(ax,'FontName',style.font,'FontSize',style.fontSize, ...
        'XColor',style.dark,'YColor',style.dark,'Color',style.paper, ...
        'TickDir','out','Box','off','LineWidth',0.7);
    hold(ax,'on');
end

function map=divergingMap(style)
    t=linspace(0,1,128)';
    low=(1-t)*style.blue+t*style.paper;
    high=(1-t(2:end))*style.paper+t(2:end)*style.orange;
    map=[low;high];
end

function writeCaptions(folder,data)
    file=fullfile(folder,'FIGURE_CAPTIONS.md');
    fid=fopen(file,'w','n','UTF-8');
    if fid<0, error('OPUS:PlotExportFailed','Cannot write figure captions.'); end
    cleaner=onCleanup(@() fclose(fid)); %#ok<NASGU>
    fprintf(fid,'# Figure captions and interpretation\n\n');
    fprintf(fid,'All differences are attacked minus no-attack control. ');
    fprintf(fid,'F = fragmentation; D = disabling. Vertical dotted, dashed, and dash-dot rules ');
    fprintf(fid,'mark F, D, and simultaneous mixed event times. ');
    fprintf(fid,'Continuous counts are expected populations, not individual incidents. ');
    fprintf(fid,'The blue-white-orange debris scale is centred on zero. ');
    fprintf(fid,'Economic values use the OPUS-based proxy, not company profit. ');
    fprintf(fid,'The palette is inspired by UniBw M public orange/blue/grey materials; ');
    fprintf(fid,'exact university CI values were not available.\n\n');
    fprintf(fid,'| Time (years) | Type | Target owner |\n| ---: | --- | --- |\n');
    for i=1:height(data.events)
        fprintf(fid,'| %.6g | %s | %s |\n',data.events.time(i), ...
            char(data.events.type(i)),char(data.events.owner(i)));
    end
    fprintf(fid,'\n**01 Active fleet:** S + Su counts and their difference. ');
    fprintf(fid,'Repeated attack timestamps show immediate pre/post jumps.\n\n');
    fprintf(fid,'**02 Debris:** Difference in shared N by altitude and time. ');
    fprintf(fid,'The altitude view includes changed and targeted shells, with two shells of context. This is shell-average model output, not a spatial debris cloud.\n\n');
    fprintf(fid,'**03 Economic trajectory:** Cumulative discounted cash-flow proxy ');
    fprintf(fid,'at recorded interval ends; plotted segments are not smoothed estimates.\n\n');
    fprintf(fid,'**04 Economic components:** Change in revenue, negated change in ');
    fprintf(fid,'spending, and their sum as the net cash-flow proxy change. ');
    fprintf(fid,'Reduced spending is shown as a positive contribution.\n\n');
    fprintf(fid,'**06 Economic development:** Each step is one model interval, annualized ');
    fprintf(fid,'by its duration. Upper panels show attacked and control revenue and ');
    fprintf(fid,'cash-flow proxy; lower panels show attacked-minus-control differences. ');
    fprintf(fid,'These are modeled economic rates, not measured company growth or profit.\n\n');
    fprintf(fid,'**08 Economic impact by shell:** Up to eight materially changed ');
    fprintf(fid,'shells are shown, plus each attacked shell and its neighbours. ');
    fprintf(fid,'The companion CSV contains all shells. Revenue change plus negated ');
    fprintf(fid,'spending change equals net discounted cash-flow change.\n\n');
    fprintf(fid,'**09 Replacement reference:** The left panel sums nominal ');
    fprintf(fid,'replacement-value references for attacked satellites. The right panel ');
    fprintf(fid,'shows the owner''s modeled discounted cash-flow difference against ');
    fprintf(fid,'its no-attack control. These are different measures and must not be ');
    fprintf(fid,'added; the left panel is not booked launch spending.\n');
end
