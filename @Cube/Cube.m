classdef Cube
    % Cube A data class for manipulating hyperspectal datacubes.
    % The Cube class is a smart wrapper for handling hyperspectral
    % datacubes and associated metadata, such as wavelengths and fwhm
    % values.
    
    % TODO: History tracking should probably be implemented as a better
    % data structure (possibly value class)

    % !!! This must be updated each time the class definition changes !!!
    % The constant properties are not saved to files, so comparing this to
    % the private Version property should reveal version changes from
    % object creation.
    properties (Constant, Hidden)
        ClassVersion = '0.9.0' % Current version of the class source
    end
    
    properties (SetAccess = 'private')
        % DATA The contained datacube in [row, column, band] order. 
        % Default: zeros(0,0,0)
        Data = zeros(0,0,0)
        
        % FILES Full path(s) of the file(s) the cube data originates from.
        % Initialized by file reader methods. Existing Files lists are
        % concatenated when two or more Cube objects are combined by some
        % operation, such as arithmetic operations.
        % Default: {} (empty cell array)
        Files = {}
        
        % QUANTITY String description of the physical quantity of the data.
        % For example, 'Reflectance' or 'Radiance'. Used internally for
        % automatic titling or labeling of plots and axes.
        % Default 'Unknown'.
        Quantity = '' % Default set by constructor
        
        % WAVELENGTHUNIT String description of the wavelength unit.
        % Unit for the Wavelength and FWHM metadata. Used internally for 
        % automatic axis labeling in visualizations.
        % Default: 'Band index' (if default Wavelength data is used)
        %          'Unknown' (if Wavelength data is supplied without unit)
        WavelengthUnit = '' % Default set by constructor
        
        % WAVELENGTH Center wavelengths for each band in the data.
        % 1 x nBands numerical vector. Used internally as an axis for
        % visualizations.
        % Default: 1:nBands
        Wavelength = [] % Default set by constructor
        
        % FWMH Full Width at Half Maximum for each band in the data.
        % 1 x nBands numerical vector.
        % Default: zeros(1,nBands)
        FWHM = [] % Default set by constructor
        
        % HISTORY Provenance information for the Cube.
        % Each Cube method that returns a new Cube appends to the result
        % history an entry (cell array) with a descriptive string of the 
        % operation, a function handle to the method and the parameters 
        % passed to it (with some exceptions to reduce needless data 
        % duplication).
        % Default: {{'Object created'}}
        History = {{'Object created'}}
        
        % Version Internal version number of the class instance. 
        % This is set at object creation time from the current class 
        % definition, and used internally by the loadobj method to check 
        % for version mismatches when loading saved Cube objects.
        Version = Cube.ClassVersion
    end
    
    % Always recalculated from the data so they are in sync
    properties (Dependent, SetAccess = 'private')
        % TYPE Numeric type of the data (dependent property).
        % Equivalent to calling class(cube.Data)
        Type
        
        % MIN Minimum value in the Cube (dependent property).
        % Equivalent to calling min(Cube.Data(:))
        Min
        
        % MAX Maximum value in the Cube (dependent property).
        % Equivalent to calling max(Cube.Data(:))
        Max
        
        % SIZE The size of the datacube (dependent property).
        % Equivalent to calling size(Cube.Data), with the exception that
        % singleton dimensions are preserved to always return a 1 x 3
        % vector for consistency, i.e.
        %  size(ones(3,2))      == [3,2]
        %  Cube(ones(3,2)).Size == [3,2,1]
        Size
        
        % AREA The number of pixels in the image (dependent property).
        % Shorthand for calculating Cube.Width times Cube.Height
        Area
        
        % BANDS The vector 1:nBands (dependent property).
        % Shorthand for 1:Cube.nBands, useful for logical indexing.
        Bands
        
        % WIDTH The width of the datacube (dependent property).
        % The number of columns in Cube.Data, equal to Cube.Size(2).
        Width
        
        % HEIGHT The height of the datacube (dependent property).
        % The number of rows in Cube.Data, equal to Cube.Size(1).
        Height
        
        % NBANDS The number of bands in the datacube (dependent property).
        % The number of bands (layers) in Cube.Data, equal to Cube.Size(3).
        nBands
    end
    
    methods
        
        %% Constructor %%
    
        function cube = Cube(varargin)
            %CUBE Construct a Cube from given data
            % Usage:
            %  c = CUBE(arr) creates a Cube object from the array arr with
            %  default metadata (and generates warnings of the fact).
            %  c = CUBE(arr, ..., 'Name', value) syntax can be used to supply
            %  the following metadata:
            %   'wl'       : 1 x N or N x 1 vector of wavelengths
            %   'wlu'      : Wavelength unit as a char array
            %   'fwhm'     : 1 x N or N x 1 vector of FWHM values
            %   'quantity' : Data quantity (e.g. 'Reflectance')
            %   'history'  : Cell array containing provenance information
            %   'file'     : Path to file of origin (must match an existing
            %                file). Usually set by a file reader such as
            %                ENVI.read.
            %
            % If given metadata does not match the array (namely,
            % wavelengths or fwhms), an error will be thrown.
            % 
            % The constructor may also be called with an existing Cube object
            % to copy the data and possibly update existing metadata:
            % c = CUBE(cube, ..., 'Name', value)
            
        if nargin > 0  % Calling without parameters explicitly does nothing.
        
            % Parse the input parameters using the customized inputParser
            CA = CubeArgs();
            CA.parse(varargin{:})
            
            data = CA.Results.data;
            qty  = CA.Results.quantity;
            file = CA.Results.file;
            wl   = CA.Results.wl;
            wlu  = CA.Results.wlunit;
            fwhm = CA.Results.fwhm;
            hst  = CA.Results.history;
            
            if CA.isCube(data)
                % If given an existing Cube object, copy and update any
                % given properties.
                cube = data;
                if ~ismember('quantity', CA.UsingDefaults)
                    cube.Quantity = qty;
                end
                if ~ismember('wl', CA.UsingDefaults)
                    cube.Wavelength = wl;
                    cube.WavelengthUnit = 'Unknown';
                end
                if ~ismember('wlunit', CA.UsingDefaults)
                    cube.WavelengthUnit = wlu;
                end
                if ~ismember('fwhm', CA.UsingDefaults)
                    cube.FWHM = fwhm;
                end
            elseif isnumeric(data)
                % If we are given a matrix, assign it as data and assign
                % metadata from the given parameters
                cube.Data = data;
                if ismember('quantity', CA.UsingDefaults)
                    warning('Cube:DefaultQuantity', 'Quantity not given, setting to %s.', qty);
                end
                cube.Quantity = qty;
                
                % Construct default values if none were given
                if ismember('wl', CA.UsingDefaults)
                    warning('Cube:DefaultWavelength', 'Wavelengths not given, using layer numbering.');
                    wl = 1:size(data,3);
                end
                
                if ismember('wlunit', CA.UsingDefaults)
                    if ismember('wl', CA.UsingDefaults)
                        warning('Cube:DefaultWavelengthUnit', 'Wavelength unit not given, setting to "Band index".');
                        wlu = 'Band index';
                    else
                        warning('Cube:UnknownWavelengthUnit', 'Wavelength unit not given, setting to "Unknown".');
                        wlu = 'Unknown';
                    end
                end
                
                if ismember('fwhm', CA.UsingDefaults)
                    warning('Cube:DefaultFWHM', 'FWHM values not given, setting to zero.');
                    fwhm = zeros(1, size(data, 3));
                end
                
                cube.Wavelength = wl;
                cube.WavelengthUnit = wlu;
                cube.FWHM = fwhm;

                cube.Files = file;
                cube.History = hst;
                % Append the given history with a note and the given
                % parameters.
                % Note that the data matrix is saved here as well, which
                % can result in large memory use.
                cube.History = {{'Cube constructed from matrix data',@Cube,CA.Results}};
            else
                error('Unknown data supplied, parameters were\n%s',evalc('CA.Results'));
            end
        end
        end
        

        %% Getters and Setters %%
        
        function value = get.Type(obj)
            value = class(obj.Data);
        end
        
        function value = get.Min(obj)
            value = min(obj.Data(:));
        end
        
        function value = get.Max(obj)
            value = max(obj.Data(:));
        end
        
        % Size, Area and Bands correspond to those given by size(obj.Data),
        % but Size is padded to include singleton dimensions.
        function value = get.Size(obj)
            switch ndims(obj.Data)
                case 3
                    value = size(obj.Data);
                case 2
                    value = [size(obj.Data),1];
                otherwise
                    error('Data dimensions otherworldly (%s). Check sanity.', mat2str(size(obj.Data)));
            end
        end
        
        % Width and height of the image. Note the order vs. Size.
        function value = get.Width(obj)
            value = obj.Size(2);
        end
        
        function value = get.Height(obj)
            value = obj.Size(1);
        end
        
        function value = get.Area(obj)
            value = obj.Width*obj.Height;
        end
        
        function value = get.nBands(obj)
            value = obj.Size(3);
        end
        
        function value = get.Bands(obj)
            value = 1:obj.nBands;
        end
        
        % Enforce that Wavelength and FWHM correspond to Data in size.
        % Checked using nBands to stay independent of possible changes
        % in implementation (namely orientation of the data matrix).
        % TODO: Does not prevent mismatches if we forget to set either
        %       when changing the data.
        function obj = set.Wavelength(obj,value)
            assert(isequal(size(value),[1,obj.nBands]) ...
                || isequal(size(value),[obj.nBands,1]), ...
                   'Cube:IncorrectWavelength', ...
                   'Given wavelengths do not match the data!');
            obj.Wavelength = reshape(value,[1,obj.nBands]);
        end
        
        function obj = set.FWHM(obj,value)
            assert(isequal(size(value),[1,obj.nBands]) ...
                || isequal(size(value),[obj.nBands,1]), ...
                   'Cube:IncorrectFWHM', ...
                   'Given FWHMs do not match the data!');
            obj.FWHM = reshape(value, [1,obj.nBands]);
        end
        
        % Enforce that file list and history are always appended.
        function obj = set.Files(obj,value)
            obj.Files = [obj.Files; value];
        end
        
        function obj = set.History(obj,value)
            obj.History = [obj.History; value];
        end
        
        % Enforce the type of Data to numeric and warn if precision
        % changes. 
        % Checked using Type to stay independent of underlying
        % implementation.
        function obj = set.Data(obj,value)
            assert(isnumeric(value),'Attempted to assign non-numeric data!');
            if ~strcmp(class(value),obj.Type) && ~isempty(obj.Data)
                warning('Data type changes from %s to %s',obj.Type,class(value));
            end
            obj.Data = value;
        end
        
        % Data quantity must be a non-empty char array
        function obj = set.Quantity(obj,value)
            assert(~isempty(value), 'Quantity must be a non-empty char array');
            assert(ischar(value), 'Quantity must be a non-empty char array');
            obj.Quantity = value;
        end
        
        %% Visualization %%    
        
        % Open a cube slicer. See slice.m
        [obj,h] = slice(obj, method)
        
        % See hist.m
        [obj, counts, edges, h] = hist(obj, normalization, edges, visualize)
        
        % See threshold_on_band.m
        [th_im] = threshold_on_band(obj, band, th_frac)
        
        % Plot pixel spectra. See plot.m
        [obj, ax] = plot(obj,h)
        
        % Display the given band as an image. See im.m
        [obj,im] = im(obj,b)
        
        % Display selected bands as RGB image. See rgb.m
        [obj,im] = rgb(obj,b)
        
        %% Rearrangement %%
        
        function obj = flipud(obj)
            %FLIPUD Flip the image upside-down
            obj.Data = flipud(obj.Data);
            obj.History = {{'Flipped upside-down',@flipud}};
        end
        
        function obj = fliplr(obj)
            %FLIPLR Flip the image left-to-right
            obj.Data = fliplr(obj.Data);
            obj.History = {{'Flipped left-to-right',@fliplr}};
        end
        
        function obj = rot90(obj, k)
            %ROT90 Rotate the image 90 degrees counterclockwise
            % ROT90(k) rotates the image k times counterclockwise in 90
            % degree increments.
            if nargin < 2
                k = 1;
            end
            
            obj.Data = rot90(obj.Data,k);
            obj.History = {{'Rotated counterclockwise k times', @rot90, k}};
        end
        
        function obj = repmat(obj, ns)
            %REPMAT Repeat the data along each dimension
            % c2 = REPMAT(c1, [ny, nx, nb]) repeats the cube c1 along each 
            % axis (height, width, bands respectively) the specified number
            % of times. Metadata will be repeated similarly if necessary
            % (i.e. nb > 1).
            % Replication factors for all dimensions must be specified or
            % an error will be thrown.
            % 
            % See also: REPMAT
            assert(isequal(size(ns), [1,3]), 'Cube:InvalidNs', 'You must specify replication factors for all dimensions ([ny, nx, nb])');
            
            obj.Data = repmat(obj.Data, ns);
            obj.Wavelength = repmat(obj.Wavelength, [1,ns(3)]);
            obj.FWHM = repmat(obj.FWHM, [1,ns(3)]);
            obj.History = {{'Repeated data', @repmat, ns}};
        end
        
        % Reshape the Cube into a list. See toList.m
        [obj] = toList(obj)
            
        % Reshape a list of spectra to an rectangular image. See fromList.m
        [obj] = fromList(obj, W, H)
            
        %% Slicing %%
    
        % Spatial crop. See crop.m
        [obj, tl, br] = crop(obj,tl,br)
        
        % Band selection. See bands.m
        [obj, b] = bands(obj,b)
        
        % Spatial masking. See mask.m
        [obj, maskim] = mask(obj,maskim)
        
        % Unmasking back to a cube. See unmask.m
        [obj, maskim] = unmask(obj,maskim)
        
        % Pixel selection. See px.m
        [obj, cx] = px(obj,cx)
        
        % Take a number of spectra (pixels). See take.m
        [obj] = take(obj,n)
        
        %% Arithmetic operations %%
        % 
        % Arithmetic operations are overloaded to support matching sized
        % Cube objects. Metadata is carried over from the first argument,
        % with the exception of Quantity, which will be set to Unknown
        % unless supplied (using e.g. plus(a,b,qty) syntax).
        
        function obj = plus(obj, x, qty)
            obj.checkOperands(obj, x);
            
            if nargin < 3
                qty = ['(', obj.Quantity, ' + ', x.Quantity, ')'];
            end
            
            obj.Data = bsxfun(@plus, obj.Data, x.Data);
            obj.Quantity = qty;
            obj.Files    = x.Files(:);
            obj.History  = {{'Added with another Cube', @plus, x.History}};
        end
        
        function obj = minus(obj, x, qty)
            obj.checkOperands(obj, x);
            
            if nargin < 3
                qty = ['(', obj.Quantity, ' - ', x.Quantity, ')'];
            end
            
            obj.Data = bsxfun(@minus, obj.Data, x.Data);
            obj.Quantity = qty;
            obj.Files    = x.Files(:);
            obj.History  = {{'Substracted by another Cube', @minus, x.History}};
        end
        
        function obj = times(obj, x, qty)
            obj.checkOperands(obj, x);
            
            if nargin < 3
                qty = ['(', obj.Quantity, ' * ', x.Quantity, ')'];
            end
            
            obj.Data = bsxfun(@times, obj.Data, x.Data);
            obj.Quantity = qty;
            obj.Files    = x.Files(:);
            obj.History  = {{'Multiplied elementwise by another Cube', @times, x.History}};
        end
        
        function obj = rdivide(obj, x, qty)
            obj.checkOperands(obj, x);
            
            if nargin < 3
                qty = ['(', obj.Quantity, ' / ', x.Quantity, ')'];
            end
            
            obj.Data = bsxfun(@rdivide, obj.Data, x.Data);
            obj.Quantity = qty;
            obj.Files    = x.Files(:);
            obj.History  = {{'Divided elementwise by another Cube', @rdivide, x.History}};
        end
        
        %% Operations %%

        % Apply function on the data. See map.m
        obj = map(obj, f, varargin)
        
        % Apply function on each spectrum. See mapSpectra.m
        obj = mapSpectra(obj, f, varargin)
        
        % Apply function on each layer (band). See mapBands.m
        obj = mapBands(obj, f, qty, res_band_multiplier)
        
        %% Reductions %%
        
        % Spatial mean. See mean.m
        obj = mean(obj, flag1, flag2)
        
        function obj = colMean(obj)
            %COLMEAN Returns the spatial mean spectra for each column.
            obj.Data    = mean(obj.Data,1);
            obj.History = {{'Reduced to spatially columnwise means',@colMean}};
        end
        
        function obj = rowMean(obj)
            %ROWMEAN Returns the spatial mean spectra for each row.
            obj.Data    = mean(obj.Data,2);
            obj.History = {{'Reduced to spatially rowwise means',@rowMean}};
        end
        
        function obj = median(obj)
            %MEDIAN Returns the spatial median spectra.
            obj.Data    = median(obj.toList.Data,1);
            obj.History = {{'Reduced to spatial median',@median}};
        end

        %% Utilities
        
        function bool = inBounds(obj,cx)
            %INBOUNDS Check whether the given indices are within bounds
            % INBOUNDS([x,y,b]) returns true only if
            %  0 < x <= width,
            %  0 < y <= height, and
            %  0 < b <= bands 
            % of the data cube for all values in x, y, b. All values in cx
            % must be integer values, else we return false.
            % INBOUNDS([x, y]) does the same without the bands check.
            
            assert(all(Utils.isnatural(cx(:))), 'Cube:UnnaturalCoordinates', ...
                'Coordinate values must be natural numbers');
            
            % isnatural checks > 0, we only need to check max bound
            if size(cx,2) > 1
                bool = all(cx(:,1)<= obj.Width) ...
                    && all(cx(:,2)<= obj.Height);
            end
            if size(cx,2) > 2
                bool = bool && all(cx(:,3) <= obj.nBands);
            end
        end
    end
    
    methods (Static)
        
        function checkOperands(a, b)
            %CHECKOPERANDS Check Cubes for arithmetic operand compatibility
            % and error if they are not matching.
            
            assert(isa(a, 'Cube') && isa(b, 'Cube'), ...
                'Cube:InvalidOperandType', ...
                'Both operands must be Cubes');
            
            bool = isequal(a.Size, b.Size);
            
            assert(bool, ...
                'Cube:OperandSizeMismatch', ...
                'Operand sizes %s and %s are incompatible',...
                mat2str(a.Size), mat2str(b.Size));
        end
        
        %% Object saving and loading 
        
        function saveToFile(obj, filename, overwrite)
            %SAVETOFILE Save cube(s) to a file
            % Cube.saveToFile(cube, filename) saves the given cube or cube
            % array, and possibly generates a filename.
            % If the filename is a directory, 
            % If the given filename does not have
            % an extension, appends '.cb'.
            % Unless the optional parameter overwrite is given and true, 
            % throws an error if the file already exists.
            if nargin < 3
                overwrite = false;
            end
            
            % Sanity checks
            assert(isa(obj,'Cube'), 'First parameter invalid, expected a valid Cube object or array.');
            assert(ischar(filename) && ~isempty(filename), 'Second parameter was invalid, expected a filename (non-empty string)');
            assert(islogical(overwrite), 'Overwrite parameter must be a logical value.');
            
            % Append '.cb' when no file extension was given
            [dir, fname, ext] = fileparts(filename);
            if strcmp(ext,'')
                fname = [fname,'.cb'];
            else
                fname = [fname,ext];
            end
            savefile = fullfile(dir,fname);
            
            % Check whether we are overwriting and act appropriately
            assert( ~exist(savefile,'file') || overwrite, ...
                'File already exists. If you want to overwrite, give true as the third parameter.');
            
            % Save the file and print some nice output
            CUBEDATA = obj;
            n = length(CUBEDATA);
            fprintf('Saving %d Cube(s) to %s\n', n, savefile);
            
            % For files over 2GB in size, only version 7.3 of the MAT
            % format is available. If it is not specified, save fails but
            % only with a warning. Since we can't know the file size
            % beforehand, default to version 7.3 always.
            save(savefile,'CUBEDATA','-mat','-v7.3');
            fprintf('Saved. File contents:\n');
            whos('-file', savefile);
        end
        
        function obj = loadFromFile(filename)
            %LOADFROMFILE Load saved cube(s)
            % C = loadFromFile(filename) attempts to read the filename,
            % which be a valid MAT file containing the variable CUBEDATA.
            % Display some output when starting and finishing loading
            fprintf('Loading Cube data from %s\n', filename);
            S = load(filename,'-mat','CUBEDATA');
            fprintf('Loaded %d Cube(s).\n',length(S.CUBEDATA));
            obj = S.CUBEDATA;
        end
        
        function obj = loadobj(s)
            %LOADOBJ Check the version of the saved class before loading
            % In case the saved version does not match the current version
            % in the class definition, throw an error and show the versions
            % if possible.
            if ~isequal(s.Version, Cube.ClassVersion)
                if ischar(s.Version) && ischar(Cube.ClassVersion)
                    warning('Saved object has version %s, while current class version is %s. Proceed with caution.',...
                        s.Version, Cube.ClassVersion);
                else
                    warning('The saved object has different version than the current class. Proceed with caution.');
                end
            end
            obj = loadobj(s);
        end
    end
end
