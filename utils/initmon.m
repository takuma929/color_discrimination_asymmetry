function initmon()
global RGBCOL;
global COLRGB;   
global monxyY;
if isempty(monxyY)
%   monxyY = [0.6130 0.3489 20.2888;
%             0.2829 0.6054 64.0547;
%             0.1565 0.0709 8.6309];

  monxyY = [0.6400 0.3300 0.2126;
            0.3000 0.6000 0.7152;
            0.1500 0.0600 0.0722];
display('STANDARD MONCIE USED')
end

x = monxyY(:,1); y = monxyY(:,2); Y = monxyY(:,3);
xyz = [x y 1-x-y];
white = Y/2;

% Smith & Pokorny cone fundamentals 
% V. C. Smith & J. Pokorny (1975), Vision Res. 15, 161-172.
M = [ 0.15514  0.54312  -0.03286
     -0.15514  0.45684   0.03286
      0.0      0.0       0.01608];

LMS = xyz*M'; % R, G  and B cones (i.e, long, middle and short wavelength)

LM_sum = LMS(:,1) + LMS(:,2); % R G sum
L = LMS(:,1)./LM_sum;
S = LMS(:,3)./LM_sum;
M = 1 - L;

% constant blue axis
a = white(1)*S(1); % rwSR
b = white(1)*(L(1)+M(1)); % rwLR
%a = (white(1)-0.5)*S(1); % rwSR
%b = (white(1)-0.5)*(L(1)+M(1)); % rwLR
c = S(2); % SG
d = S(3); % SB
e = L(2)+M(2); % LG
f = L(3)+M(3); % LB

dGcb = (a*f/d - b)/(c*f/d - e); % solve x gx
dBcb = (a*e/c - b)/(d*e/c - f); % solve y bx
%dGcb = (a*f/d - b)/(c*f/d - e)+white(2); % solve x gx
%dBcb = (a*e/c - b)/(d*e/c - f)+white(3); % solve y bx

% tritanopic confusion axis
a = white(3)*L(3); % bwLB
%a = white(3)*S(3); % bwSB
b = white(3)*M(3); % bwMB
%a = (white(3)-0.5)*L(3);
%b = (white(3)-0.5)*M(3);

c = L(1); % LR
d = L(2); % LG

e = M(1); % MR
f = M(2); % MG

dRtc = (a*f/d - b)/(c*f/d - e); % solve x gy
dGtc = (a*e/c - b)/(d*e/c - f); % solve y ry

%dRtc = (a*f/d - b)/(c*f/d - e)+white(2); % solve x gy
%dGtc = (a*e/c - b)/(d*e/c - f)+white(1); % solve y ry

IMAX = 1;

COLRGB = IMAX * [1        1         dRtc/white(1)
                 1  -dGcb/white(2)  dGtc/white(2)
                 1  -dBcb/white(3)     -1];
             
RGBCOL = inv(COLRGB);

end