function [dkl] = toDKL(rgb)
global RGBCOL;
global COLRGB;
% save probe
if (isempty(COLRGB))
    initmon;
end
dkl = (rgb - 0.5) * RGBCOL';
% % change S axis - MT 01/12/2015
% dkl(:,3)=-dkl(:,3);
end