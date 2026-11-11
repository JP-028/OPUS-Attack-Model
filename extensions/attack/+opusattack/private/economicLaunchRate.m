function rates=economicLaunchRate(decisions,launches,ids)
% Update the complete decision ledger after economic rows have been solved.
    rates=decisions.launch_rate;
    for row=1:height(decisions)
        i=find(strcmp(ids,decisions.owner_id{row}),1);
        rates(row)=launches.(decisions.population{row})(decisions.shell(row),i);
    end
end
