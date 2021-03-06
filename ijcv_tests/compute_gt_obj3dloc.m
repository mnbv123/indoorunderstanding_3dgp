function [ data ] = compute_gt_obj3dloc( data, annofile )

gtvp = load(annofile);
data.anno.campar.f  = gtvp.K_gt(1,1)/gtvp.gt_resizefactor;  % converted back to original image scale
data.anno.campar.u0 = gtvp.K_gt(1,3)/gtvp.gt_resizefactor;
data.anno.campar.v0 = gtvp.K_gt(2,3)/gtvp.gt_resizefactor;
data.anno.campar.p  = gtvp.angle_gt.pitch;
data.anno.campar.y  = gtvp.angle_gt.yaw;
data.anno.campar.r  = gtvp.angle_gt.roll;

% K_gt = gtvp.K_gt./gtvp.gt_resizefactor;
K_gt = gtvp.K_gt;
K_gt(1:2,:) = K_gt(1:2,:)/gtvp.gt_resizefactor;
R_gt = gtvp.R_gt;

% this should be used instead above
data.anno.campar.K = K_gt;
data.anno.campar.R = R_gt;

% % K and R for computing gt object 3d location
% K_bp = [data.anno.campar.f                  0 data.x.imsz(2)/2; ...
%                          0 data.anno.campar.f data.x.imsz(1)/2; ...
%                          0                  0                1];
% % R_bp =[1 0 0;0 1 0;0 0 1];
% 
% data.anno.campar.K_bp = K_bp;
% % data.anno.campar.R_bp = R_bp;

dets = convert2dets(data.anno);

[hobjs, invalid_idx] = generate_object_hypotheses(data.x.imfile, K_gt, R_gt, data.anno.campar.y, objmodels(), dets);
% [hobjs, invalid_idx] = generate_object_hypotheses(data.x.imfile, K_bp, R_gt, data.anno.campar.y, objmodels(), dets);
hobjs(invalid_idx) = []; dets(invalid_idx, :) = [];

data.anno.hobjs = hobjs;

bottoms = zeros(1, length(hobjs));
for i = 1:length(hobjs)
    cube =  hobjs(i).cubes(:,:,14);  % default
    bottoms(i) = -min(cube(2, :));
end

[ data.anno.camheight, data.anno.alpha ] = optimizeObjectScales( bottoms );

end

function dets = convert2dets(anno)

dets = zeros(length(anno.obj_annos), 8);
for i = 1:length(anno.obj_annos)
    dets(i, 1)   = anno.obj_annos(i).objtype;
    dets(i, 2)   = anno.obj_annos(i).subid;
    dets(i, 3)   = anno.obj_annos(i).azimuth;
    dets(i, 4:7) = [anno.obj_annos(i).x1 anno.obj_annos(i).y1 anno.obj_annos(i).x2 anno.obj_annos(i).y2];
    dets(i, 8)   = 1;
end

end