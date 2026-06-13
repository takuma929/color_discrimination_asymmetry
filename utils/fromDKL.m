function [rgb] = fromDKL(dkl,trim)
    if nargin <2;trim=0;end
    
    global RGBCOL;
    global COLRGB;
    % dkl(:,3)=-dkl(:,3);% change S axis - MT 01/12/2015
    if (isempty(COLRGB))
        initmon;
    end
    rgb = COLRGB * dkl';
    maxval = max(max(abs(rgb)));
    if trim==0
    if maxval > 0.5
        % Rescale out-of-gamut values back into range.
        rgb = rgb/(2*maxval);
    end
    end
    
    rgb = rgb+0.5;
end