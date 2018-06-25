function f=openFocusWindow(varargin)
% fig = openFocusWindow(ch) opens a Focus window with plots of the data
% contained in a single channel. There is no limit to the number of
% different Focus windows that can be open at a given time, but naturally a
% large number will put more strain on computer resources.

ch=varargin{3};
fprintf('Focusing on %g!\n',ch);