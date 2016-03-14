%run_sp.m
%Sam Gallagher
%8 March 2016
%
%This program will run the HTM and manage most UI with file IO, settings,
%and output. LOTS of work to be done here, and algorithm isn't finished
%yet, so it is a work in progress. The following menu is an ideal
%functionality.
%
%The algorithm will hold the state of the cells and columns in a file so
%that the algorithm continues to learn even when the program closes and
%reopens with new data. This is more flexible than just learning single
%sequences, though much more data is required for proper functionality. 
%
%The user can clear the column and cell states by going to edit ->
%clear memory. To view the current state, the user must go to view ->
%column states or view -> cell states or view->output.
%
%There is a help section which must outline the functionality of the
%algorithm (from OneNote notes), and can link to the white paper.
%
%The color scheme of the output can be controlled, for fun.
%
%The main display of the program is the input-to-be-sent, in a black and
%white image format subplot of sorts.

%% TODO: Store region state (input current state to region()?), work regions one time step at a time
%% Main Program
function run_htm()
%% Initialize window and variables
    %The program will need to store the numbers of everything for the
    %different regions, time, as well as the data currently being sent in, and
    %the output of each region, as a minimum. 
    
    send = []; %This is the data to-be-sent
    data_size = 0;
    htm_time = 0;
    
    n.time = 0; %Start timer at 0, go to 1 once it starts
    columns = [];
    n.regions = 1;
    activeColumns = [];
    cells = [];
    output = [];
    regionConfig.synThreshold = 0;
    regionConfig.synInc = 0;
    regionConfig.synDec = 0;
    n.dendrites = 0;
    regionConfig.minSegOverlap = 0;
    n.cols = 0;
    regionConfig.desiredLocalActivity = 0;
    n.neighborhood = 0;
    regionConfig.inputRadius = 0;
    regionConfig.boostInc = 0;
    regionConfig.minActiveDuty = 0;
    regionConfig.minOverlapDuty = 0;
    n.cells = 0;
    n.segs = 0;
    regionConfig.LearningRadius = 0;
    regionConfig.minOverlap = 0;
    
    defaultConfig = [0.2;0.075;-0.05;0.5;10;0.3;5;20;120;0.5;0.1;0.1;3;12;50;2]; %Settings according to computer readings
    %After data is input, the percentages will need to be updated.
    defaultConfig = [defaultConfig, defaultConfig, defaultConfig, defaultConfig, defaultConfig];
    
    regions = [regionConfig regionConfig regionConfig regionConfig regionConfig]; %five blank region configs
    allN = [n n n n n]; %Each region has its own n structure
    
    if exist('config') ~= 7
        mkdir config;
    end
    
    if exist('config/config.htm') == 2
        %load up pre-existing settings
        inputConfig = load('config/config.htm');
        for j = 1:5
            [regionConfig, n] = set_config( regionConfig,n,inputConfig(:,j));
            regions(j) = regionConfig;
            allN(j) = n;
        end 
        currentConfig = inputConfig;
    else
        save config/config.htm defaultConfig -ascii;
        for j = 1:5
            [regionConfig, n] = set_config( regionConfig,n,defaultConfig(:,j));
            regions(j) = regionConfig;
            allN(j) = n;
        end
        currentConfig = defaultConfig;
    end
    
    %Declarations
    %Create a window and menu
    h.fig = figure();
    h.fig.MenuBar = 'none';
    h.fig.Position = [400,100,700,700];
    
    h.toolBar = subplot(4,4,[1:4]);%This just takes up space
    h.toolBar.Visible = 'off';
    %Now create a text showing the time, which will be updated
    timeString = ['total time = ' num2str(htm_time) ',   seq length = ' num2str(allN(1).time)];
    hTimeText = uicontrol(h.fig, 'Style','text','String',timeString,'Position',[20,600,350,40],'FontSize',20);
    
    %Show the current input
    h.mainWindow = subplot(4,4,[5:16]);
    h.mainWindow.XTickLabel = [];
    h.mainWindow.YTickLabel = [];
    h.mainWindow.XGrid = 'on';
    h.mainWindow.YGrid = 'on';
    
    colors = [[1,1,1];[0,0,0]];
    colormap(colors);
    
    hFileMenu = uimenu(h.fig,'Label','File');
        hNewFile = uimenu(hFileMenu,'Label','New...');
            hData = uimenu(hNewFile,'Label','Data');
                uimenu(hData,'Label','Import data file','Callback',@cbFNFDIDF);
                uimenu(hData,'Label','Create random data','Callback',@cbFNFDCRD);
            uimenu(hNewFile,'Label','Drawing','Callback',@cbFNFDr);
        uimenu(hFileMenu,'Label','Save memory','Callback',@cbFSM);
        uimenu(hFileMenu,'Label','Open','Callback',@cbFO);
        uimenu(hFileMenu,'Label','Close','Callback',@cbFC); 
    hEditMenu = uimenu(h.fig,'Label','Edit');
        hClearMem = uimenu(hEditMenu,'Label','Clear Memory','Callback',@cbECM,'Enable','off'); %Can't clear until started
        uimenu(hEditMenu,'Label','Chart predictions over time','Callback',@cbECPOT);
        uimenu(hEditMenu,'Label','Debug','Callback',@cbED);
    hPropMenu = uimenu(h.fig,'Label','Properties');
        uimenu(hPropMenu,'Label','Edit hierarchy','Callback',@cbPEH);
        uimenu(hPropMenu,'Label','Files...','Callback',@cbPF);
        uimenu(hPropMenu,'Label','Training settings','Callback',@cbPTS);
    hRunMenu = uimenu(h.fig,'Label','Run');
        hRunItem = uimenu(hRunMenu,'Label','Run...','Callback',@cbRR,'Enable','off'); %Can't run without data
    hViewMenu = uimenu(h.fig,'Label','View');
        uimenu(hViewMenu,'Label','Color scheme','Callback',@cbVCoSc);
        hColStates = uimenu(hViewMenu,'Label','Column states','Callback',@cbVCoSt,'Enable','off'); %Can't show outputs until
        hCellStates = uimenu(hViewMenu,'Label','Cell states','Callback',@cbVCeSt,'Enable','off');   %CLA has begun
        hRegionOut = uimenu(hViewMenu,'Label','Region output','Callback',@cbVRO,'Enable','off');
    hHelpMenu = uimenu(h.fig,'Label','Help');
        uimenu(hHelpMenu,'Label','HTM White Paper (web)','Callback',@cbHHTMWP);
        uimenu(hHelpMenu,'Label','CLA Theory Tutorial','Callback',@cbHCLATT);
        uimenu(hHelpMenu,'Label','CLA Program Tutorial','Callback',@cbHCLAPT);
        uimenu(hHelpMenu,'Label','About','Callback',@cbHA);
        
    %Every one of these will need a callback, so this will
    %get pretty hairy, as tends to happen. To keep things easy,
    %a system of naming will be put in place: 'cb'+first letter of parent
    %menu, and label words. Ex. View -> Column states = cbVCS
    %Exceptions are where there are multiple that fit that, in which case
    %it'll contain the first TWO letters of the words. e.g. View
    %-> Column States = cbVCoSt

%% Menu callback functions
%FILE MENU CALLBACKS
    %NEW FILE CALLBACKS
        function cbFNFDr(hObject,evt)
            %New drawing
            send = generate_input();
            hClearMem.Enable = 'on';
            
            send_sz = size(send);
            send_img = vec2mat( send(:,1)+1, floor( sqrt(send_sz(1)) ) );
            send_img = rot90(send_img);
            h.img = image(send_img,'Parent',h.mainWindow);
            hold on;
            h.mainWindow.XTick = (0:floor(sqrt( send_sz(1) )) )+0.5;
            h.mainWindow.YTick = (0:floor(sqrt( send_sz(1) )) )+0.5;
            h.mainWindow.XTickLabel = [];
            h.mainWindow.YTickLabel = [];
            h.mainWindow.XGrid = 'on';
            h.mainWindow.YGrid = 'on';
            
            if ~isempty(send)
                %hRunItem.Enable = 'on';
                data_size = size(send);
                data_size = data_size(1);
                allN(1).dendrites = floor(allN(1).dendrites*data_size);
                allN(1).cols = floor(allN(1).cols*data_size);
                %update percentages in currentConfig (NOT config file)
                currentConfig(4,:) = currentConfig(4,:)*data_size;
                currentConfig(6,:) = currentConfig(6,:)*data_size;
                hRunItem.Enable = 'off';
            end
        end
        %DATA CALLBACKS
            function cbFNFDIDF(hObject,evt)
                %Import data file
                
                [dFileName dFileLoc] = uigetfile('*.*');
                dataFilePath = [dFileLoc dFileName];
                %Determine what type of file it is
                %Run the proper function
                %Acceptable files:
                %   jpg
                %   png
                %   txt
                %   mpg?
                %   mp3
                if ~isempty(send)
                    hRunItem.Enable = 'off';
                    data_size = size(send);
                    data_size = data_size(1);
                    allN(1).dendrites = floor(allN(1).dendrites*data_size);
                    allN(1).cols = floor(allN(1).cols*data_size);
                    %update percentages in currentConfig (NOT config file)
                    currentConfig(4,:) = currentConfig(4,:)*data_size;
                    currentConfig(6,:) = currentConfig(6,:)*data_size;
                end
            end
            function cbFNFDCRD(hObject,evt)
                %Create random data
                
                if ~isempty(send)
                    hRunItem.Enable = 'off';
                    data_size = size(send);
                    data_size = data_size(1);
                    allN(1).dendrites = floor(allN(1).dendrites*data_size);
                    allN(1).cols = floor(allN(1).cols*data_size);
                    %update percentages in currentConfig (NOT config file)
                    currentConfig(4,:) = currentConfig(4,:)*data_size;
                    currentConfig(6,:) = currentConfig(6,:)*data_size;
                end
            end
    function cbFO(hObject,evt)
        %Open
    end
    function cbFSM(hObject,evt)
        %Save memory
    end
    function cbFC(hObject,evt)
        %Close
        close(); %This is temporary
    end
%EDIT MENU CALLBACKS
    function cbECM(hObject,evt)
        %Clear memory
    end
    function cbECPOT(hObject,evt)
        %Chart predictions over time
    end
    function cbED(hObject,evt)
        %Debug
    end
%PROPERTIES MENU CALLBACKS
    function cbPEH(hObject,evt)
        %Edit hierarchy
        if isempty(send)
            error = msgbox('Warning: No input data. Deciding on parameters for regions will not be able to set data appropriately.');
            waitfor(error);
            [n.regions tempConfig] = hierarchy_ui(n.regions,send,currentConfig, false);
            if ~isempty(tempConfig)
                currentConfig = tempConfig;
                %update percentages of the config
            end
            for j = 1:5
                [regionConfig, n] = set_config( regions(j),n,inputConfig(:,j));
                regions(j) = regionConfig;
                allN(j) = n;
                allN(j).dendrites = floor(allN(j).dendrites*data_size);
                allN(j).cols = floor(allN(j).cols*data_size);
            end 
        else
            [n.regions tempConfig] = hierarchy_ui(n.regions,send,currentConfig, true);
            if ~isempty(tempConfig)
                currentConfig = tempConfig;
                hRunItem.Enable = 'on';
            end
            for j = 1:5
                [regionConfig, n] = set_config( regions(j),n,inputConfig(:,j));
                regions(j) = regionConfig;
                allN(j) = n;
                allN(j).dendrites = floor(allN(j).dendrites*data_size);
                allN(j).cols = floor(allN(j).cols*data_size);
            end 
        end

    end
    function cbPF(hObject,evt)
        %Files...
    end

    function cbPTS(hObject,evt)
        %Training settings
    end
%RUN MENU CALLBACKS
    function cbRR(hObject,evt)
        %Run
        id = 1;
        [columns, activeColumns, cells, output] = region(send,currentConfig(:,id),id);
        hColStates.Enable = 'on';
        hCellStates.Enable = 'on';
        hRegionOut.Enable = 'on';
        
        %update time information
        seqTimeElapsed = size(send);
        seqTimeElapsed = seqTimeElapsed(2);
        allN(1).time = seqTimeElapsed;
        htm_time = htm_time+allN(1).time;
        
        %quickly update the t= text
        timeString = ['total time = ' num2str(htm_time) ',   seq time = ' num2str(allN(1).time)];
        hTimeText.String = timeString;
%         for levels = 1:n.regions
%             [n, columns, activeColumns, cells, output] = region( send );
%             send = [];
%             for i = 1:20
%                 send = [send output];
%             end
%         end
        
    end
%VIEW MENU CALLBACKS
    function cbVCoSc(hObject,evt)
        %Color scheme
    end
    function cbVCoSt(hObject,evt)
        %Column states
        column_visualizer(send, columns, allN(1).cols,1); %TODO Make these more clear about what they are for the user
        show_active_columns(allN(1),activeColumns,1);
    end
    function cbVCeSt(hObject,evt)
        %Cell states
    end
    function cbVRO(hObject,evt)
        %Region output
        show_active_columns(allN(1),activeColumns,allN(1).time);
    end
%HELP MENU CALLBACKS
    function cbHHTMWP(hObject,evt)
        %HTM White Paper
    end
    function cbHCLATT(hObject,evt)
        %CLA Theory Tutorial
    end
    function cbHTMPT(hObject,evt)
        %CLA Program Tutorial
    end
    function cbHA(hObject,evt)
        %About
    end
end