function files=exportPaperFigure(fig,folder,stem)
% Export both print-ready vector artwork and a preview at fixed page size.
    drawnow;
    pdf=fullfile(folder,[stem '.pdf']);
    png=fullfile(folder,[stem '.png']);
    exportgraphics(fig,pdf,'ContentType','vector','BackgroundColor','white');
    exportgraphics(fig,png,'Resolution',250,'BackgroundColor','white');
    close(fig);
    files=string({pdf;png});
end
