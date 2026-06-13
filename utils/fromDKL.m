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
        if maxval < .5 + .000001
            fprintf('very small epsilon\n')
        end
    %     error('Out of Range')
    %    fprintf('fromDKL: out of range error maxval=%g dkl = %g %g %g rgb = %g %g %g\n', maxval, dkl(1), dkl(2), dkl(3), rgb(1), rgb(2), rgb(3));
        rgb = rgb/(2*maxval);
       fprintf('CORRECTED rgb: %g %g %g\n', rgb(1), rgb(2), rgb(3));
    end
    end
    
    rgb = rgb+0.5;
end