clear

addPaths;

if(~exist('./dataset', 'dir'))
    system('powershell ls')
    system('powershell wget http://www.eecs.umich.edu/vision/data/cvpr13IndoorData.tar.gz -outfile cvpr13IndoorData.tar.gz');
    system('powershell mv cvpr13IndoorData.tar.gz ./dataset/; cd dataset/; tar xvf cvpr13IndoorData.tar.gz; rm cvpr13IndoorData.tar.gz; cd ..');
    %mkdir('dataset');
    %system('wget http://www.eecs.umich.edu/vision/data/cvpr13IndoorData.tar.gz');
    %system('mv cvpr13IndoorData.tar.gz ./dataset/; cd dataset/; tar xvf cvpr13IndoorData.tar.gz; rm cvpr13IndoorData.tar.gz; cd ..');
end

% Tells where to find folder of images to run code on
imgbase = './dataset/cvpr13data/images/';

preprocess_dir = 'cache/test';
if(~exist(preprocess_dir, 'dir'))
    r = input('Download preprocessed data? (y) or run all preprocessing? (n)', 's');
    if(r == 'y')
        mkdir('cache');
        system('powershell wget http://www.eecs.umich.edu/vision/data/cvpr13IndoorPreprocessed.tar.gz -outfile cvpr13IndoorPreprocessed.tar.gz'); 
        system('powershell mv cvpr13IndoorPreprocessed.tar.gz ./cache/; cd cache; tar xvf cvpr13IndoorPreprocessed.tar.gz; rm cvpr13IndoorPreprocessed.tar.gz; cd ..');
        %system('wget http://www.eecs.umich.edu/vision/data/cvpr13IndoorPreprocessed.tar.gz'); 
        %system('mv cvpr13IndoorPreprocessed.tar.gz ./cache/; cd cache; tar xvf cvpr13IndoorPreprocessed.tar.gz; rm cvpr13IndoorPreprocessed.tar.gz; cd ..');
    else
        % This is for if you want to train on your own data? 
        % Populates cache folder with generated data based on the dataset
        % folder
        % Maybe this means all training data must have both photos and
        % annotations?
		disp('WARNING: preprocessing may take several hours to a day (depending on the computing power).')
        disp('Please let it run, relax and check back later!');
        % preprocess data
        basedir = './dataset/cvpr13data/images/';
        annodir = './dataset/cvpr13data/annotations/';
        
        load('dataset/cvpr13data/datasplit.mat');
        for i = 1:length(trainfiles)
            [~, path] = strtok(trainfiles{i}, '/');
            trainfiles{i} = path(2:end);
        end
        for i = 1:length(testfiles)
            [~, path] = strtok(testfiles{i}, '/');
            testfiles{i} = path(2:end);
        end
		fprintf('running object detector... '); tic();
        preprocess_detector(basedir, 'cache/detections/', testfiles);
        toc();

        % layout estimator
		fprintf('running layout estimator ... '); tic();
        curdir = pwd();
        cd 3rdParty/SpatialLayout/spatiallayoutcode/
        preprocess_layout(fullfile(curdir, basedir), fullfile(curdir, 'cache/layouts/'), testfiles, 'test');
        cd(curdir);
        toc();
        
        % scene classifier
		fprintf('running scene classifier ... '); tic();
        preprocess_sceneclass(basedir, 'cache/scene', 'test', testfiles);
		toc();
        
        % build data compatible to 3DGP code (estimate 3D model, collect all necessary info, etc)
		fprintf('estimate 3D model + etc ... '); tic();
        preprocess_data(basedir, 'cache/', annodir, 'test', testfiles);
		toc();
    end
end
%% load pre-processed data
datafiles = dir(fullfile(preprocess_dir, '*.mat'));

%% run 3DGP model for all test set
% load trained baseline model
paramfile = 'model/params_baseline'; % without 3DGP
temp = load(paramfile);
params1 = temp.paramsout;
params1.numsamples = 1000;
params1.pmove = [0 0.4 0 0.3 0.3 0 0 0];
params1.accconst = 3;

% load trained 3DGP model
paramfile = 'model/params_3dgp';
temp = load(paramfile);
params2 = temp.paramsout;
params2.numsamples = 1000;
params2.pmove = [0 0.4 0 0.3 0.3 0 0 0];
params2.accconst = 3;
params2.retainAll3DGP = 1;

% initialize buffer
res = cell(1, length(datafiles));
annos = cell(1, length(datafiles));
xs = cell(1, length(datafiles));
conf0 = cell(1, length(datafiles)); % baseline
conf1 = cell(1, length(datafiles)); % no 3DGP
conf2 = cell(1, length(datafiles)); % 3DGP with Marginalization 1
conf3 = cell(1, length(datafiles)); % 3DGP with Marginalization 2

erroridx = false(1, length(datafiles));
csize = 32;

myPool = parpool;
for idx = 1:csize:length(datafiles)
    setsize = min(length(datafiles) - idx + 1, csize);
    fprintf(['processing ' num2str(idx) ' - ' num2str(idx + setsize)]);
    
    for i = 1:setsize
        tdata(i) = load(fullfile(preprocess_dir, datafiles(idx+i-1).name));
    end    
    tdata(setsize+1:end) = [];
    
    tempres = cell(1, setsize);
    tconf0 = cell(1, setsize);
    tconf1 = cell(1, setsize);
    tconf2 = cell(1, setsize);
    tconf3 = cell(1, setsize);
    
    terroridx = false(1, setsize);
    parfor i = 1:setsize
        pg0 = parsegraph(); 

        pg0.layoutidx = 1; % initialization
        pg0.scenetype = 1;

        params = params2;
        [tdata(i).iclusters] = clusterInteractionTemplates(tdata(i).x, params.model);
        %%%%% baseline  %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        params = params1;
        [tempres{i}.spg, tempres{i}.maxidx, tempres{i}.h, tempres{i}.clusters] = infer_top(tdata(i).x, tdata(i).iclusters, params, pg0);
        params.objconftype = 'orgdet';
        [tconf0{i}] = reestimateObjectConfidences(tempres{i}.spg, tempres{i}.maxidx, tdata(i).x, tempres{i}.clusters, params);
        params.objconftype = 'odd';
        [tconf1{i}] = reestimateObjectConfidences(tempres{i}.spg, tempres{i}.maxidx, tdata(i).x, tempres{i}.clusters, params);
        %%%%% 3DGP      %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        params = params2;
        [tempres{i}.spg, tempres{i}.maxidx, tempres{i}.h, tempres{i}.clusters] = infer_top(tdata(i).x, tdata(i).iclusters, params, pg0);
        params.objconftype = 'odd'; % M1 in the paper
        [tconf2{i}] = reestimateObjectConfidences(tempres{i}.spg, tempres{i}.maxidx, tdata(i).x, tempres{i}.clusters, params);
        params.objconftype = 'odd2'; % M2 in the paper
        [tconf3{i}] = reestimateObjectConfidences(tempres{i}.spg, tempres{i}.maxidx, tdata(i).x, tempres{i}.clusters, params);
        tempres{i}.clusters = [];
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    end
    erroridx(idx:idx+setsize-1) = terroridx;
    
    for i = 1:setsize
        res{idx+i-1} = tempres{i};
        annos{idx+i-1} = tdata(i).anno;
        xs{idx+i-1} = tdata(i).x;
        conf0{idx+i-1} = tconf0{i};
        conf1{idx+i-1} = tconf1{i};
        conf2{idx+i-1} = tconf2{i};
        conf3{idx+i-1} = tconf3{i};
    end
    fprintf(' => done\n')
end
delete(myPool)
%% draw detection evaluation curves
om = objmodels();
for i = 1:length(om)-1
    subplot(2,3,i);
    
    [rec, prec, ap0]= evalDetection(annos, xs, conf0, i, 0, 0, 1);
    plot(rec, prec, 'r--', 'linewidth', 2);
    hold on;
    [rec, prec, ap1]= evalDetection(annos, xs, conf1, i, 0, 0, 1);
    plot(rec, prec, 'g-.', 'linewidth', 2);
    [rec, prec, ap2]= evalDetection(annos, xs, conf2, i, 0, 0, 1);
    plot(rec, prec, 'k', 'linewidth', 2);
    [rec, prec, ap3]= evalDetection(annos, xs, conf3, i, 0, 0, 1);
    plot(rec, prec, 'b-.', 'linewidth', 2);
    hold off;
    
    h = title(om(i).name);
    set(h, 'fontsize', 30);
    grid on;
    axis([0 1 0 1]);
    h = gca;
    set(h, 'fontsize', 18);
    
    h = xlabel('recall');
    set(h, 'fontsize', 30);
    h = ylabel('precision');
    set(h, 'fontsize', 30);
    
    h = legend({['DPM AP=' num2str(ap0, '%.03f')], ...
            ['NO 3DGP AP=' num2str(ap1, '%.03f')], ...
            ['3DGP-M1 AP=' num2str(ap2, '%.03f')], ...
            ['3DGP-M2 AP=' num2str(ap3, '%.03f')]}, ...
            'Location', 'SouthWest', 'fontsize', 20);
    drawnow
end

%% test and visualize
datalist = 20;

params = params2;
params.objconftype = 'odd'; % M1 in the paper

pg0 = parsegraph(); 
pg0.layoutidx = 1; % initialization
pg0.scenetype = 1;

% Switch the following lines to process all images 
%for dataidx = 1:datalist
for dataidx = datalist
    
    % Test data for image at index dataidx
    data = load(fullfile(preprocess_dir, datafiles(dataidx).name));
    
    fprintf('the thing we are loading is ');
    disp(datafiles(dataidx).name);
    
    fprintf('it is located in ');
    disp(fullfile(preprocess_dir, datafiles(dataidx).name));
    % necessary if downloaded the preprocessed data  
    
    % This is a copy of the function get_im_file.m in the ijcv_tests directory
    if(~exist(data.x.imfile, 'file'))
        [~, fname] = strtok(data.x.imfile, '/');
        [~, fname] = strtok(fname, '/');
        
        % This is where the image that is to be modeled is specified 
        data.x.imfile = fullfile(imgbase, fname);
    end
    fprintf("data.x.imfile is ");
    disp(data.x.imfile);
    
    [iclusters] = clusterInteractionTemplates(data.x, params.model);
    [spg, maxidx, h, clusters] = infer_top(data.x, iclusters, params, pg0);

    [oconf] = reestimateObjectConfidences(spg, maxidx, data.x, clusters, params);
    nmspg = getNMSgraph(spg(maxidx), data.x, clusters, oconf);

    %show2DGraph(nmspg, data.x, clusters, 1);
    
    fprintf("data.x.imfile is ")
    disp(data.x.imfile)
    
    %fprintf("data is ")
    %disp(data)
    
    fprintf("data.x.corners 1,1 is ")
    celldisp(data.x.corners(1,1))
    % data.x.corners is a 2 x 4 array where some values can be NaN
    % Perhaps these are corners of bounding boxes for objects? In the 
    % final model the scale is an order of 100 times smaller though 
    
    fprintf("clusters is ")
    disp(clusters)
    
    fprintf("nmspg is ")
    disp(nmspg)
    % nmspg is a dictionary of information about the scene 
    % Generates plot with 3D coordinates along xyz axis
    show3DGraph(nmspg, data.x, clusters, 2); 
    pause(2)
end
