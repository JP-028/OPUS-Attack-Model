function dz = flowRhs(z,model)
% Integrate flow counters along with the physical state (no logging side effects).
    x=[max(z(1:model.stateSize),0);1];
    f=model.definition;
    rates=f.coefficient.*x(f.left_index).*x(f.right_index);
    S=sum(reshape(x(1:model.block),model.n,model.m),2);
    Su=sum(reshape(x(2*model.block+1:3*model.block),model.n,model.m),2);
    active=S+Su;
    shares=zeros(model.n,2);
    occupied=active>0;
    shares(occupied,1)=S(occupied)./active(occupied);
    shares(occupied,2)=Su(occupied)./active(occupied);
    mask=f.share_type>0;
    rates(mask)=rates(mask).*shares(sub2ind(size(shares),f.shell(mask),f.share_type(mask)));
    dz=[model.routing*rates;rates];
end
