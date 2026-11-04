function validateDisablingPhysics(V,population)
% A shared D class can retain active properties only when the classes match.
    source=1;
    if string(population)=="Su", source=4; end
    for name={'mass','A','diameter','beta'}
        key=name{1};
        if ~isfield(V,key)
            error('OPUS:IncompatibleDisablingPhysics','Disabling requires configured %s values.',key);
        end
        values=V.(key);
        validateattributes(values,{'numeric'},{'vector','numel',4,'real','finite','nonnegative'});
        if values(source)~=values(2)
            error('OPUS:IncompatibleDisablingPhysics', ...
                'Cannot retain %s properties in D: %s differs between the active and derelict classes.',population,key);
        end
    end
    if V.mass(2)<=0 || V.A(2)<=0 || V.diameter(2)<=0
        error('OPUS:IncompatibleDisablingPhysics','Satellite mass, area and diameter must be positive.');
    end
end
