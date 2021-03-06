classdef ENVITest < matlab.unittest.TestCase
    
    properties
       testCube
    end
    
    properties (ClassSetupParameter)
        height = struct('row',    1, ...
                        'small',  3, ...
                        'large', 10  ...
                        )
                    
        width  = struct('column', 1, ...
                        'small',  3, ...
                        'large', 10  ...
                        )
                    
        nbands = struct('single',   1, ...
                        'rgb',      3, ...
                        'multi',    5, ...
                        'hyper',  100  ...
                        );
    end

    methods (TestClassSetup)
        function createCube(testCase, width, height, nbands)
           data = gallery('uniformdata', [height, width, nbands], 1);
           wls  = gallery('uniformdata', [1, nbands], 1);
           fwhms= gallery('uniformdata', [1, nbands], 2);
           
           testCase.testCube = Cube(data, ...
               'quantity', 'Testdata',...
               'wlu', 'nm', 'wl', wls, 'fwhm', fwhms);
        end
    end
    
    methods (Test)
        function writeReadDataIdentity(testCase)
            % Writing a Cube to ENVI and reading it back should not change
            % the data.

            orig = testCase.testCube;
            tmpfile = tempname;
            
            ENVI.write(orig, tmpfile);
            new = ENVI.read([tmpfile, '.dat']);
            delete([tmpfile, '.dat']);
            delete([tmpfile, '.hdr']);
            
            testCase.verifyEqual(new.Data, orig.Data);
        end
        
        function writeReadMetaIdentity(testCase)
            % Writing a Cube to ENVI preserves wavelength and fwhm
            % metadata (up to 6 decimals)
            orig = testCase.testCube;
            tol = 1e-6;
            tmpfile = tempname;
            
            ENVI.write(orig, tmpfile);
            new = ENVI.read([tmpfile, '.dat']);
            delete([tmpfile, '.dat']);
            delete([tmpfile, '.hdr']);
            
            testCase.verifyEqual(new.WavelengthUnit, orig.WavelengthUnit, 'Wavelength unit changed');
            testCase.verifyLessThan(abs(new.Wavelength - orig.Wavelength), tol, 'Wavelengths changed');
            testCase.verifyLessThan(abs(new.FWHM - orig.FWHM), tol, 'Wavelengths changed');
        end
        
        function writeHeaderFileExistsError(testCase)
            % Unless overwrite is set, write should error when the 
            % hdr file exists

            cube = testCase.testCube;
            tmpfile = tempname;
            
            % Create an empty .hdr file
            fclose(fopen([tmpfile, '.hdr'],'w'));
           
            testCase.verifyError(@()ENVI.write(cube, tmpfile),'ENVI:ExistingHeaderFile');
            delete([tmpfile, '.hdr']);
        end
        
        function writeDataFileExistsError(testCase)
            % Unless overwrite is set, write should error when the 
            % data file exists

            cube = testCase.testCube;
            tmpfile = tempname;
            
            % Create an empty .hdr file
            fclose(fopen([tmpfile, '.dat'],'w'));
           
            testCase.verifyError(@()ENVI.write(cube, tmpfile),'ENVI:ExistingDataFile');
            delete([tmpfile, '.dat']);
        end
        
        function writeFileOverwrite(testCase)
            % When overwrite is set, write should overwrite the files
            
            orig = testCase.testCube;
            tmpfile = tempname;
            
            % Create an empty .hdr and dat files
            fclose(fopen([tmpfile, '.dat'],'w'));
            fclose(fopen([tmpfile, '.hdr'],'w'));
            
            % Write over the empty file
            ENVI.write(orig, tmpfile, 'overwrite');
            
            % Read the file and check that we did overwrite it
            new = ENVI.read([tmpfile, '.dat']);
            
            testCase.verifyEqual(new.Data, orig.Data);
            
            delete([tmpfile, '.dat']);
            delete([tmpfile, '.hdr']);
        end
        
        function readDefaultQuantity(testCase)
            % ENVI format does not contain the quantity, so reading a file
            % without specifying it should result in Unknown quantity
            orig = testCase.testCube;
            tmpfile = tempname;
            
            ENVI.write(orig, tmpfile);
            new = ENVI.read([tmpfile, '.dat']);
            delete([tmpfile, '.dat']);
            delete([tmpfile, '.hdr']);
            
            testCase.verifyEqual(new.Quantity, 'Unknown');
        end
        
        function readSuppliedQuantity(testCase)
            % If a quantity is supplied, the Cube returned by ENVI.read
            % should match the one given
            orig = testCase.testCube;
            tmpfile = tempname;
            
            ENVI.write(orig, tmpfile);
            new = ENVI.read([tmpfile, '.dat'], orig.Quantity);
            delete([tmpfile, '.dat']);
            delete([tmpfile, '.hdr']);
            
            testCase.verifyEqual(new.Quantity, orig.Quantity);
        end
        
        function findhdrFileNotFound(testCase)
            % findhdr should throw an error if the file does not exist
            tmpfile = [tempname, '.hdr'];
            testCase.assumeEqual(exist(tmpfile, 'file'),0);
            testCase.verifyError(@()ENVI.findhdr(tmpfile),'ENVI:HeaderNotFound');
        end
    end
end