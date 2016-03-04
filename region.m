%region.m
%Sam Gallagher
%15 February
%
%This function manages a region that is given an input. The input must
%consist of all data to-be-input in columns, with each column representing
%a time step. Random inputs can be generated to test functionality with the
%generate_input.m file. Output is an OR of the active and predictive cells.

function output = region(dInput)
    %% To begin, run the user_control panel
    [synThreshold,synInc,synDec,nDendrites,minSegOverlap,nCols,desiredLocalActivity,Neighborhood,inputRadius,boostInc,minActiveDuty,minOverlapDuty,nCells,nSegs,LearningRadius,minOverlap] = user_control(size(dInput));
    
    %Getting our data straight.
    data_size = size(dInput);
    nCols = floor(nCols*data_size(1));
    
    segment.locations = [];
    segment.perm = [];
    segment.synCon = [];
    segment.overlap = 0;
    segment.active = 0;
    segment.sequence = false;
    
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
    
    n.dendrites = floor(nDendrites*data_size(1));
    n.cols = nCols;
    n.cellpercol = nCells;
    n.cells = nCells*nCols;
    n.segments = nSegs;
    n.neighborhood = Neighborhood;
    
    cell.col = 0;     %cell column
    cell.layer = 0;   %cell layer
    cell.segs = [];   %This holds the segments
    cell.state = [];  %The cell state is an array of states over time
    cell.permFlag = false; %This is true when the changes are temporary, false when they are permanent
    
    %% Generate proximal segments 
    columns = [];
    
    for iter = 1:n.cols
        %To select a center, we need to
        %account for the fact that nCols < data_size. We can multiply each
        %column center then, by the inverse of nCols. For
        %example, with 100 input bits and 30 columns, column 1 will have
        %its center at position 1/30th of the way into the input, at
        %100*(1/30), and taking the floor.
        
        col.center = floor(data_size(1)*(iter/nCols));
        [col.locations col.perm col.synCon] = make_proximal_segment(n.dendrites,inputRadius, data_size(1), col.center,synThreshold);
        
        columns = [columns col];
    end
    
    %% Generate cells and their distal synapses
    
    n.hoods = ceil(n.cols/n.neighborhood);
    activeColumns = zeros(desiredLocalActivity*n.hoods,data_size(2));
    
    %% Now we'll go into a time-step loop
    for t = 1:data_size(2)
        %For each timestep, find overlaps for the columns and reset
        %activity and sums
        for c = 1:n.cols
            columns(c).active = 0;
            columns(c).overlap = compute_overlap(dInput(:,t),columns(c),minOverlap);
            if columns(c).overlap > 0
                columns(c).overlapSum = columns(c).overlapSum + 1; %update rolling sum
            end
        end
        
        %% Select Active Columns
        %Send each neighborhood to the inhibitor, store the result as the
        %active column list. 

        %There are a few ways to handle this neighborhoods part. The first
        %is to split the columns into neighborhoods like 1-10, 11-20, etc.
        %The other option would be to observe the radius for each column,
        %so 1-5, 1-6 (for col 2) ... 20-30 for col 25, and so on. This
        %causes columns to be evaluated more than once, but this may not be
        %a bad thing, as long as a column is not selected to 'win' more
        %than once.
        for iter = 0:n.hoods-1
            start = n.neighborhood*(iter)+1;
            stop = min(start+(n.neighborhood-1),n.cols); %make sure it doesn't go over the max ncols
            o = [ columns(start:stop).overlap ];
            
            w = inhibit_cols(o,desiredLocalActivity);
            if w == -1
                tempA = -1;
            else
                tempA = transpose(w+start-1);
            end
            
            for c = 1:n.cols
                if(any( c == tempA ))
                    columns(c).active = 1;
                    columns(c).activeSum = columns(c).activeSum+1;%update rolling sum
                end
            end
        end

        %Now, what if the neighborhoods overlapped each other at each
        %point? What change in the total number of active columns selected
        %will we see?
        %activeColumns2 = 0;
        %for colCenter = 1:n.cols
        %    start = max(colCenter - Neighborhood/2, 1);
        %    stop = min(colCenter + Neighborhood/2, n.cols);
        %    n = columnOverlaps(t,start:stop);
        %    activeColumns2 = [inhibit_cols(n,desiredLocalActivity)+start, activeColumns2];
        %end
        %activeColumns2 = unique(activeColumns2(activeColumns2 ~= 0));
        %sort(activeColumns2);

        %% Use active columns to update synapses
        
        %This loop checks if a synapse is connected, and updates it
        %based on whether or not it is, for every position in the
        %column c
        for c = 1:n.cols
            if columns(c).active
                for i = 1:n.dendrites
                    if columns(c).synCon(i) == 1
                        if dInput(columns(c).locations(i)) == 1
                            %There are assignment issues here, replacing
                            %synCon
                            [columns(c).perm(i) columns(c).synCon(i)] = update_s(columns(c).perm(i),columns(c).synCon(i), synThreshold,synInc);
                        else
                            [columns(c).perm(i) columns(c).synCon(i)] = update_s(columns(c).perm(i),columns(c).synCon(i), synThreshold,synDec);
                        end
                    end
                end
                
                %Let's update the cells now, with the active columns. 
                %We need to see what cells were expected to be active at
                %this time step, i.e. what cells were predicting the
                %previous time step. 
            end
        
            
            %Update the minimum active duty cycle to meet before being
            %boosted. 1% of the max active duty cycle in the neighborhood
            minActiveDuty = 0.01*max( [columns( max(1,(c-Neighborhood/2)):min(n.cols,(c+Neighborhood/2)) ).actDuty] );
            
            %update the duty cycles for activity and overlaps-above-minimum
            columns(c).actDuty = columns(c).activeSum / t;
            columns(c).oDuty = columns(c).overlapSum / t;
            
            if columns(c).actDuty < minActiveDuty
                columns(c).boost = columns(c).boost + boostInc;
            end
            
            if columns(c).oDuty < minOverlapDuty
                %increase all synapse permanences by 0.1*synapse threshold
                for i = 1:n.dendrites
                    columns(c).perm(i) = columns(c).perm(i)+0.1*synThreshold;
                end
            end
        end
        w = find_active_columns(columns,n.cols);
        nActive = size(w);
        nActive = nActive(2);
        if ~(isempty(w))
            activeColumns(1:nActive,t) = w;
        end
        
        %% Now Update our cells for the temporal memory
        
    end
    activeColumns
    %% Visualize our data
    column_visualizer(dInput, columns, n.cols,1);
    show_active_columns(n.cols,activeColumns,data_size(2));
    output = columns;
end