function [ fig_num ] = plotPipeline( locations, pt_cloud, state, img, fig_num, num_candidates_history, num_matched_kp_history, frame_num )
%PLOTPIPELINE Summary:
%   Creates 4 plots:
%   - current image with available candidate and tracked keypoints
%   - number of tracked landmarks over the last 20 frames
%   - full trajectory
%   - pointcloud and trajectory over the last 20 frames
%
%   Input arguments
%   - locations:                3 x L matrix of all locations up to this point
%   - state:                    parameter struct describing the current state
%   - img:                      the current image matrix
%   - fig_num:                  the number of the figure generated in the first
%                               iteration
%   - num_candidates_history:   1 x 20 matrix describing the number of
%                               tracked keypoint candidates over the last
%                               20 frames
%   - num_matched_keypoints_history:    1 x 20 matrix describing the number of
%                                       matched keypoint candidates over the last
%                                       20 frames 
%   - frame_num:                the current frame number
%   Output arguments:
%   - fig_num:                  the number of the figure generated in the
%                               first iteration



candidates = state.candidates;
matched_kp = state.matched_kp;

%% Initialize figure if first iteration

if isnan(fig_num)
    fig = figure('units','normalized','outerposition',[0 0 1 1]);
    fig_num = fig.Number;
else
    figure(fig_num);
end


%% Text Box with frame number

mTextBox = uicontrol('style','text');
set(mTextBox,'String',sprintf('Frame Number: %d',frame_num));
set(mTextBox,'Units','normalized');
set(mTextBox,'Position',[0.0,0.97,0.1,0.03]);
set(mTextBox,'FontSize',12);

%% Plot image with currently available candidates and currently matched keypoints

subplot(2,4,[1,2])

cla();
imshow(img)
hold on;
plot(candidates(1,:),candidates(2,:),'bx', 'Linewidth', 2, 'Markersize', 3);
plot(matched_kp(1,:),matched_kp(2,:),'gx', 'Linewidth', 2);
daspect([1 1 1]);
pbaspect([1 1 1]);
title('Current Image');
hold off;

legend('Candidate KP','Matched KP')

%% Plot number of tracked landmarks and candidates over the last 20 frames
subplot(2,4,5)
cla();
hold on;
plot(num_matched_kp_history,'g-','LineWidth',2);
plot(num_candidates_history,'b-.','LineWidth',2);
pbaspect([4 5 1]);
axis([0 20 0 1000]);
title('Number of Keypoints');
legend('Landmarks', 'Candidates');
hold off;
legend('Matched KP','Candidate KP')

%% Plot full trajectory
subplot(2,4,6) 
plot3(locations(1,:),locations(2,:),locations(3,:),'b-','LineWidth',2);
view([0,-1,0]);
daspect([4 1 5]);
pbaspect([4 1 5]);
title('Full Trajectory');
hold off;

%% Plot pointcloud and trajectory over the last 20 frames


scale = norm(locations(:,end) - locations(:,end - 1));
subplot(2,4,[3,4,7,8])
plot_last = size(locations,2) - 20;
if plot_last < 1
    plot_last = 1;
end
cla();
hold on;
plot3(locations(1,plot_last:end),locations(2,plot_last:end),locations(3,plot_last:end),'b-','LineWidth',2);
pcshow(pt_cloud','VerticalAxis','y','VerticalAxisDir','down','MarkerSize',45);
view([0,-1,0]);
pbaspect([4 1 5]);
xlim([locations(1,end) - 50*scale, locations(1,end) + 50*scale])
ylim([locations(2,end) - 50*scale, locations(2,end) + 50*scale])
zlim([locations(3,end) - 50*scale, locations(3,end) + 50*scale])
title('Trajectory and Landmarks over the last 20 Frames');
hold off;

legend('Trajectory','Matched KP','Location','northeast');

end




