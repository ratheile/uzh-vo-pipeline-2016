function [ R, T, curr_state, debug_data,duration_data, plot_pose ] = processFrame(curr_img, prev_img, prev_state, K, params, varargin)
%PROCESSFRAME Determines pose of camera with next_image in frame of
% camera with prev_img. Determine point_cloud <-> keypoint correspondence
% with keypoints from next image and point cloud from prev img.
%
% inputs: curr_img: N x M key frame image of camera
%         prev_img: N x M image of camera
%         prev_state: struct with the following fields:
%                     pt_cloud: 3 x L array with 3D points that have been
%                               generated so far.
%                     matched_kp: 2 x L array with 2D key points in
%                                 prev_img which have a corresponding 3D point in
%                                 pt_cloud
%                     candidate_kp: 2 x P array with 2D key points which
%                                   have been tracked from some frame before
%                                   but not matched with a 3D point
%                     kp_track_start: 2 x P starting key point for each
%                                     track
%                     kp_pose_start: 12 x P starting pose for each key
%                                    point
%
%         K: calibration matrix of camera with curr_img
%
% outputs: curr_state: state propagated to current time frame (same structure
%                      as prev_state
%          curr_T: 3D points that are in 1 to 1 correspondence
%                            with curr_keypoints and are in frame of camera
%                            with prev_img
%          R_next: rotation of camera with next_img with respect to prev_img.
%          T_next: translation of camera with next_img with respect to
%                  prev_img.


%
% Optional output
% duration_data
%
%
%






%# valid parameters, and their default values
pnames = {'debug', 'track_duration'};
dflts  = {'false', 'false'};

%# parse function arguments
[debug, track_duration] = internal.stats.parseArgs(pnames, dflts, varargin{:});

%# use the processed values: clr, lw, ls, txt
%# corresponding to the specified parameters
%# ...

pt_cloud = prev_state.pt_cloud; % pt_cloud w. r. t. last key frame
curr_matched_kp = prev_state.matched_kp; % keypoints (matched with pt_cloud)
candidates_prev = prev_state.candidates;
candidates_start = prev_state.candidates_start;
candidates_start_pose = prev_state.candidates_start_pose;
prev_cam_transformation = prev_state.cam_transformation;


if (track_duration )
    duration_data = [];
end

%% Step 1: State Propagation
if (track_duration) tic; end;
[curr_matched_kp, point_validity] = propagateState(curr_matched_kp, prev_img, curr_img);

% remove lost points
curr_matched_kp = curr_matched_kp(:, point_validity);
pt_cloud = pt_cloud(:,point_validity);

if (track_duration) 
    duration_data = [duration_data, toc];
end

%% Step 2: Pose Estimation
if (track_duration) tic; end;
% with new correspondence pt_cloud <-> curr_matched_kp determine new pose with RANSAC and P3P
[R, T, inlier_mask] = ransacLocalizationSpecial(curr_matched_kp, pt_cloud, K, params);

% correct displacements that are not in the general direction of the
% previous orientation
curr_pose = - R' * T;
prev_pose = - prev_cam_transformation(:, 1:3)' * prev_cam_transformation(:, 4);

heading1 = prev_cam_transformation(:,3);
heading2 = R(:,3);

displacement = curr_pose - prev_pose;
angle1 = 180 / pi * acos(dot(heading1, displacement) / norm(displacement));
angle2 = 180 / pi * acos(dot(heading2, displacement) / norm(displacement));
angle3 = 180 / pi * acos(dot(heading1, heading2));

% if the pose is unrealistic correct it by projecting it in direction of
% the heading
abs([angle3 - angle1, angle3 - angle2]);
if max(abs([angle3 - angle1, angle3 - angle2])) > 180  % new pose outside a cone of 110 degrees left and right.
    plot_pose = false;
else
    plot_pose = true;
end

% remove all outliers from ransac
curr_matched_kp = curr_matched_kp(:, inlier_mask);
pt_cloud = pt_cloud(:, inlier_mask);

if (track_duration)
    duration_data = [duration_data, toc];
end

%% Step 3: Triangulating new landmarks
if (track_duration) tic; end;
if ~isempty(candidates_prev)
    
    % Track candidate keypoints
    [candidates_prev, point_validity] = propagateState(candidates_prev, prev_img, curr_img);
    
    % Remove lost candidate keypoints
    candidates_prev = candidates_prev(:, point_validity);
    candidates_start = candidates_start(:, point_validity);
    candidates_start_pose = candidates_start_pose(:, point_validity);
    
    % Try to triangulate points (with triangulation check if possible)
    [new_pt_cloud, new_matched_kp, remain] = ...
        tryTriangulate(candidates_prev, candidates_start, candidates_start_pose, [R,T], K, params);
    
    
    % Remove successfully triangulated candidates
    candidates_prev = candidates_prev(:, remain);
    candidates_start = candidates_start(:, remain);
    candidates_start_pose = candidates_start_pose(:, remain);
    
    % add new 3d points and matched key points
    pt_cloud = [pt_cloud, new_pt_cloud];
    curr_matched_kp = [curr_matched_kp, new_matched_kp];
end

if (track_duration)
    duration_data = [duration_data, toc];
end

%% Establish new keypoint candidates for current frame
if (track_duration) tic; end;
if  size(candidates_prev,2) <= params.candidate_cap
    
    num_keypoints =  params.add_candidate_each_frame;

    scores = harris(curr_img, params.harris_patch_size, params.harris_kappa);
    if params.surpress_existing_matches==1
        scores = suppressExistingMatches(scores, [candidates_prev, curr_matched_kp], ...
            params.nonmaximum_supression_radius);
    end
    new_candidate_kp = selectKeypoints(scores, num_keypoints, params.nonmaximum_supression_radius);
    
    % add them to existing candidate keypoints
    candidates_prev = [candidates_prev, new_candidate_kp];
    candidates_start = [candidates_start, new_candidate_kp];
    
    candidates_start_pose = [candidates_start_pose, repmat(reshape([R,T], 12, 1), 1, size(new_candidate_kp,2))];
end

if (track_duration)
    duration_data = [duration_data, toc];
end

%% Write all variables to new state
curr_state = struct('pt_cloud', pt_cloud, ...
    'matched_kp', curr_matched_kp, ...
    'candidates', candidates_prev, ...
    'candidates_start', candidates_start, ...
    'candidates_start_pose', candidates_start_pose, ...
    'cam_transformation', [R, T]);

assert(size(candidates_prev, 2) == size(candidates_start, 2));
assert(size(candidates_prev, 2) == size(candidates_start_pose, 2));

%% Calcuate debug struct
if debug
    debug_data = struct( ...
        'curr_matched_kp', curr_matched_kp, ...
        'Matched', size(curr_matched_kp, 2), ...
        'Cloud', size(pt_cloud, 2), ...
        'Candidates', size(candidates_prev, 2));
    
    %Plot key values
    struct('Matched', size(curr_matched_kp, 2), ...
        'Cloud', size(pt_cloud, 2), ...
        'Candidates', size(candidates_prev, 2));
else
    debug_data = struct();
end

end

