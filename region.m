%region.m
%Sam Gallagher
%15 February
%
%This function manages a region that is given an input. The input must
%consist of all data to-be-input in columns, with each column representing
%a time step. Random inputs can be generated to test functionality with the
%generate_input.m file. 
%
%Output is an OR of the active and predictive cells,
%and the n structure (number of columns, cells, etc), the columns
%structure, and the cells structure

function [columns,activeColumns,cells,prediction,output] = region(dInput,inputConfig,id,columns,cells,nRegions,nextConfig, temporal_memory, spatial_pooler,TM_delay,dbg,reps)
    %% To begin, get our data straight.
    synThreshold = inputConfig(1);
    synInc = inputConfig(2);
    synDec = inputConfig(3);
    nDendrites = inputConfig(4); % percentage
    minSegOverlap = inputConfig(5);
    n.cols = inputConfig(6); % percentage
    
    desiredLocalActivity = inputConfig(7);
    Neighborhood = inputConfig(8);
    inputRadius = inputConfig(9);
    boostInc = inputConfig(10);
    minActiveDuty = inputConfig(11); % percentage
    minOverlapDuty = inputConfig(12); % percentage
    nCells = inputConfig(13);
    nSegs = inputConfig(14);
    LearningRadius = inputConfig(15);
    minOverlap = inputConfig(16);
    
    data_size = size(dInput);
    
    segment.locations = [];
    segment.perm = [];
    segment.synCon = [];
    segment.overlap = 0;
    segment.active = 0;
    segment.sequence = false;
    segment.cell = -1;
    segment.index = -1;
    
    queue = []; %segment queue
    %The queue is FIFO
    
    if isempty(columns)
        col.center = 0;
        col.perm = [];
        col.synCon = [];
        col.overlap = 0;
        col.overlapSum = 0; %used for rolling avg
        col.active = 0;
        col.activeSum = 0; %used for rolling avg
        col.locations = [];
        col.boost = 1;
        col.actDuty = 1.0;
        col.oDuty = 1.0;
        col.burst = false;
        col.learning_cell = -1;
        col.active_cell = -1;
    end
    
    n.data = data_size(1);
    n.time = data_size(2);
    n.dendrites = floor(nDendrites*n.data);
    n.cols = floor(n.cols*data_size(1));
    n.cellpercol = nCells;
    n.cells = nCells*n.cols;
    n.segments = nSegs;
    n.neighborhood = Neighborhood;
    n.hoods = ceil(n.cols/n.neighborhood);
    
    if isempty(cells)
        cell.col = 0;     %cell column
        cell.layer = 0;   %cell layer
        cell.segs = [];   %This holds the segments
        cell.nseg = 0;
        cell.state = [];  %The cell state is an array of states over time
                %cell states: 0 is inactive, 1 is active, 2 is predicting
        cell.tempFlag = false; %This is true when the changes are temporary, false when they are permanent
        cell.learn = [];
        cell.mknewseg = false;
        cell.active = [];
    end
    %% Generate columns and proximal segments on the first run
    if spatial_pooler
        if isempty(columns)

            columns = [];
            waitbox = waitbar(0,'Initializing columns...');
            for iter = 1:n.cols
                waitbar(iter/n.cols);
                %To select a center, we need to
                %account for the fact that n.cols < data_size. We can multiply each
                %column center then, by the inverse of n.cols. For
                %example, with 100 input bits and 30 columns, column 1 will have
                %its center at position 1/30th of the way into the input, at
                %100*(1/30), and taking the floor.

                col.center = floor(n.data*(iter/n.cols));
                [col.locations col.perm col.synCon] = make_proximal_segment(n.dendrites,inputRadius, n.data, col.center,synThreshold);

                columns = [columns col];
            end
            close(waitbox);
        end
    else
        for iter = 1:n.cols
            columns = [columns col];
        end
    end
    
    %% Generate cells if [cells] is empty
    if isempty(cells)
        cells = [];

        for i = 1:n.cols
            for j = 1:n.cellpercol
                cell.col = i;
                cell.layer = j;
                cell.state(1) = 0; %We know all cells are inactive

                cells = [cells cell];
            end
        end
    end
    
    activeColumns = zeros(desiredLocalActivity*n.hoods,n.time);
    
    %Main loop
    if id == 1
        waitbox = waitbar(0,'Running HTM...');
    end
    for R = 1:reps
        for t = 1:n.time
            if id == 1
                waitbar((t+n.time*R-1)/(n.time*reps));
            end
            if TM_delay > 0
                [columns, cells, tempPrediction, n, output,tempActiveColumns] = update_region(columns, cells, 0,dInput(:,t),n,synThreshold,...
                    synInc,synDec,minSegOverlap,desiredLocalActivity,boostInc, minActiveDuty, ...
                    minOverlapDuty, minOverlap,LearningRadius,segment,t,queue, false, spatial_pooler);
                activeColumns(1:n.active,t) = tempActiveColumns;
                prediction(1:n.cols,t) = tempPrediction;
                %send the information on to the next region if it exists
    %             if numel(nextConfig(1,:)) > 1
    %                 %output, inputConfig, id, columns, cells, nRegions, nextConfig,
    %                 %temporal, spatial, delay
    %                 [columns2, activeColumns2, cells2, output2] = region(output,nextConfig(:,1),id+1,[],[],nRegions,nextConfig(:,(id+1):nRegions),spatial_pooler,temporal_memory, TM_delay);
    %             elseif numel(nextConfig(1,:)) == 1
    %                 [columns2, activeColumns2, cells2, output2] = region(output,nextConfig(:,1),id+1,[],[],nRegions,[],spatial_pooler,temporal_memory,TM_delay);
    %             end
                TM_delay = TM_delay-1;
            else
                [columns, cells, tempPrediction, n, output,tempActiveColumns] = update_region(columns, cells, 0,dInput(:,t),n,synThreshold,...
                    synInc,synDec,minSegOverlap,desiredLocalActivity,boostInc, minActiveDuty, ...
                    minOverlapDuty, minOverlap,LearningRadius,segment,t,queue, temporal_memory, spatial_pooler,dbg);
                activeColumns(1:n.active,t) = tempActiveColumns;
                prediction(1:n.cols,t) = tempPrediction;
                %send the information on to the next region if it exists
                if numel(nextConfig(1,:)) > 1
                    [columns2, activeColumns2, cells2, output2] = region(output,nextConfig(:,1),id+1,[],[],nRegions,nextConfig(:,(id+1):nRegions),spatial_pooler,temporal_memory,TM_delay,dbg);
                elseif numel(nextConfig(1,:)) == 1
                    [columns2, activeColumns2, cells2, output2] = region(output,nextConfig(:,1),id+1,[],[],nRegions,[],spatial_pooler,temporal_memory,TM_delay,dbg);
                end

                TM_delay = TM_delay-1;
            end
        end
    end
    close(waitbox);
    
end