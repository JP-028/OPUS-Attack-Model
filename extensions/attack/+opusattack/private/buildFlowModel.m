function model = buildFlowModel(launches,V,n,m,ids)
% Compile the original MOCAT equations as attributed expected population flows.
% Each flow removes one source object and adds yield destination objects.
% Ordered same-species pairs preserve upstream S^2/D^2 conventions; these
% contributions must NOT be interpreted as distinct physical collision events.
    block=n*m; stateSize=3*block+n; one=stateSize+1;
    S=reshape(1:block,n,m); D=S+block; Su=S+2*block; N=(3*block+(1:n))';
    rows=cell(0,16);
    for k=1:n
        p=V.phi/V.V(k); dest=min(k,V.k_star);
        for i=1:m
            add('launch',k,k,ids{i},'', 'S','','S',ids{i},0,S(k,i),1,launches.S(k,i),one,one,0);
            add('launch',k,k,ids{i},'', 'Su','','Su',ids{i},0,Su(k,i),1,launches.Su(k,i),one,one,0);
            for kind=1:2
                if kind==1, source=S(k,i); pop='S'; else, source=Su(k,i); pop='Su'; end
                add('retirement_to_derelict',k,dest,ids{i},'',pop,'','D',ids{i}, ...
                    source,D(dest,i),1,(1-V.P)/V.Dt,source,one,0);
                add('retirement_removal',k,0,ids{i},'',pop,'','','', ...
                    source,0,0,V.P/V.Dt,source,one,0);
            end
            encounter(S(k,i),'S',ids{i},N(k),'N','',D(k,i),p(1,3),V.K0(1,3));
            encounter(Su(k,i),'Su',ids{i},N(k),'N','',D(k,i),p(3,4),V.K0(3,4));
            add('derelict_collision_loss',k,k,ids{i},'','D','N','N','', ...
                D(k,i),N(k),V.K0(2,3),p(2,3),D(k,i),N(k),0);
            if k>1
                add('drag_transfer',k,k-1,ids{i},'','D','','D',ids{i}, ...
                    D(k,i),D(k-1,i),-V.Dhl/V.Dhu,V.dragOutD(k),D(k,i),one,0);
            else
                add('boundary_exit',k,0,ids{i},'','D','','','',D(k,i),0,0,V.dragOutD(k),D(k,i),one,0);
            end
            for j=1:m
                encounter(S(k,i),'S',ids{i},D(k,j),'D',ids{j},D(k,i),p(1,2),V.K0(1,2));
                encounter(Su(k,i),'Su',ids{i},D(k,j),'D',ids{j},D(k,i),p(2,4),V.K0(2,4));
                add('active_collision_loss',k,k,ids{i},ids{j},'S','S','N','', ...
                    S(k,i),N(k),V.K0(1,1),(1-V.slot_par)*V.alpha_active*p(1,1),S(k,i),S(k,j),0);
                add('active_collision_loss',k,k,ids{i},ids{j},'Su','Su','N','', ...
                    Su(k,i),N(k),V.K0(4,4),V.alpha_active*p(4,4),Su(k,i),Su(k,j),0);
                % The two directed losses sum to alpha_active*phi*S*Su.
                % Their debris outputs sum to upstream C11, without duplication.
                add('active_collision_loss',k,k,ids{i},ids{j},'S','Su','N','', ...
                    S(k,i),N(k),V.K0(1,4),V.alpha_active*p(1,4),S(k,i),Su(k,j),1);
                add('active_collision_loss',k,k,ids{j},ids{i},'Su','S','N','', ...
                    Su(k,j),N(k),V.K0(1,4),V.alpha_active*p(1,4),S(k,i),Su(k,j),2);
                add('derelict_collision_loss',k,k,ids{i},ids{j},'D','D','N','', ...
                    D(k,i),N(k),V.K0(2,2),p(2,2),D(k,i),D(k,j),0);
            end
        end
        add('debris_generation',k,k,'','','N','N','N','',0,N(k),V.K0(3,3),p(3,3),N(k),N(k),0);
        if k>1
            add('drag_transfer',k,k-1,'','','N','','N','',N(k),N(k-1),-V.Dhl/V.Dhu,V.dragOutN(k),N(k),one,0);
        else
            add('boundary_exit',k,0,'','','N','','','',N(k),0,0,V.dragOutN(k),N(k),one,0);
        end
    end
    names={'process','shell','destination_shell','owner_id','counterpart_owner_id', ...
        'population','counterpart_population','destination_population','destination_owner_id', ...
        'source_index','destination_index','yield','coefficient','left_index','right_index','share_type'};
    model.definition=cell2table(rows,'VariableNames',names);
    f=model.definition; count=height(f); col=(1:count)';
    from=f.source_index>0; to=f.destination_index>0;
    model.routing=sparse([f.source_index(from);f.destination_index(to)], ...
        [col(from);col(to)],[-ones(sum(from),1);f.yield(to)],stateSize,count);
    model.stateSize=stateSize;
    model.n=n; model.m=m; model.block=block;

    function encounter(source,pop,owner,other,otherPop,otherOwner,targetD,phi,K)
        add('collision_damage',k,k,owner,otherOwner,pop,otherPop,'D',owner, ...
            source,targetD,1,V.delta*phi,source,other,0);
        add('collision_destruction',k,k,owner,otherOwner,pop,otherPop,'N','', ...
            source,N(k),K,V.alpha*phi,source,other,0);
    end
    function add(process,shell,destinationShell,owner,partner,pop,partnerPop,destinationPop,destinationOwner,from,to,yield,coefficient,left,right,share)
        rows(end+1,:)={process,shell,destinationShell,owner,partner,pop,partnerPop, ...
            destinationPop,destinationOwner,from,to,yield,coefficient,left,right,share};
    end
end
