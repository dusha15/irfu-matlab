classdef mms_sdp_dmgr < handle
  %MMS_SDP_DMGR data storage container for MMS/SDP
  %   Creates one container for one MMS spacecraft
  %
  %  DATAC = mms_sdp_dmgr(scId[,procId,tmMode,samplerate])
  %
  %  See also: mms_constants
  
  properties (SetAccess = protected )
    adc_off = [];     % comp ADC offsets
    aspoc = [];       % src ASPOC file
    calFile = [];     % name of calibration file used
    CMDModel = [];    % comp CMDmodel
    dce = [];         % src DCE file
    dce_xyz_dsl = []; % comp E-field xyz DSL-coord
    dcv = [];         % src DCV file
    defatt = [];      % src DEFATT file
    defeph = [];      % src DEFEPH file
    delta_off = [];   % comp delta offsets
    dfg = [];         % src DFG file
    hk_101 = [];      % src HK_101 file
    hk_105 = [];      % src HK_105 file
    hk_10e = [];      % src HK_10E file
    l2a = [];         % src L2A file
    phase = [];       % comp phase
    probe2sc_pot = [];% comp probe to sc potential
    sc_pot = [];      % comp sc potential
    spinfits = [];    % comp spinfits
  end
  properties (SetAccess = immutable)
    CONST = [];       % constants
    samplerate = [];  % sampling rate
    procId = [];      % process ID
    tmMode = [];      % telemetry mode
    scId = [];        % spacecraft ID
  end
  
  methods
    function DATAC = mms_sdp_dmgr(scId,procId,tmMode,samplerate)
      %MMS_SDP_DMGR  conctructor for mms_sdp_dmgr class
      DATAC.CONST = mms_constants();
      MMS_CONST = DATAC.CONST;
      if nargin == 0
        errStr = 'Invalid input for scId';
        irf.log('critical', errStr); error(errStr);
      end
      
      if  ~isnumeric(scId) || ...
          isempty(intersect(scId, MMS_CONST.MMSids))
        errStr = 'Invalid input for scId';
        irf.log('critical', errStr); error(errStr);
      end
      DATAC.scId = scId;
      
      if nargin < 2 || isempty(procId)
        DATAC.procId = 1;
        irf.log('warning',['procId not specified, defaulting to '''...
          MMS_CONST.SDCProcs{DATAC.procId} ''''])
      elseif ~isnumeric(procId) || ...
          isempty(intersect(procId, 1:numel(MMS_CONST.SDCProcs)))
        errStr = 'Invalid input for init_struct.procId';
        irf.log('critical', errStr); error(errStr);
      else, DATAC.procId = procId;
      end
      
      if nargin < 3 || isempty(tmMode)
        DATAC.tmMode = 1;
        irf.log('warning',['tmMode not specified, defaulting to '''...
          MMS_CONST.TmModes{DATAC.tmMode} ''''])
      elseif ~isnumeric(tmMode) || ...
          isempty(intersect(tmMode, 1:numel(MMS_CONST.TmModes)))
        errStr = 'Invalid input for init_struct.tmMode';
        irf.log('critical', errStr); error(errStr);
      else, DATAC.tmMode = tmMode;
      end
      
      if nargin < 4 || isempty(samplerate)
        % Normal operations, try to identify sample rate from TmMode
        if(~isfield(MMS_CONST.Samplerate, MMS_CONST.TmModes{DATAC.tmMode}))
          irf.log('warning', ['init_struct.samplerate not specified,'...
            'nor found in MMS_CONST for ',MMS_CONST.TmModes{DATAC.tmMode}]);
          if iscell(MMS_CONST.Samplerate.(MMS_CONST.TmModes{1}))
            % Some modes (slow/brst) may have multiple sample rates, use the first.
            samplerate = MMS_CONST.Samplerate.(MMS_CONST.TmModes{1}){1};
          else
            samplerate = MMS_CONST.Samplerate.(MMS_CONST.TmModes{1});
          end
          irf.log('warning', ['Defaulting samplerate to ', num2str(samplerate)]);
          DATAC.samplerate = samplerate;
        else
          % Automatic, determined by tmMode.
          if iscell(MMS_CONST.Samplerate.(MMS_CONST.TmModes{DATAC.tmMode}))
            % Slow & Brst may have multiple sample rates.
            samplerate = MMS_CONST.Samplerate.(MMS_CONST.TmModes{DATAC.tmMode}){1};
          else
            samplerate = MMS_CONST.Samplerate.(MMS_CONST.TmModes{DATAC.tmMode});
          end
          DATAC.samplerate = samplerate;
        end
      else
        % Commissioning, or brst & slow, sample rate identified previously.
        DATAC.samplerate = samplerate;
      end
    end % mms_sdp_dmgr
    
    function set_param(DATAC,param,dataObj)
      %SET_PARAM  assign a parameteter do dataobj
      %
      %  set_param(DATAC,param,dataObj)
      MMS_CONST = DATAC.CONST;
      
      % Make sure first argument is a dataobj class object,
      % otherwise a read cdf file.
      if isa(dataObj,'dataobj') % do nothing
      elseif ischar(dataObj) 
        if ~exist(dataObj, 'file')
          errStr = ['File not found: ' dataObj];
          irf.log('critical', errStr);
          error('MATLAB:MMS_SDP_DMGR:INPUT', errStr);
        end
        % If it is not a read cdf file, is it an unread cdf file? Read it.
        irf.log('warning',['Loading ' param ' from file: ', dataObj]);
        dataObj = dataobj(dataObj);
      elseif isstruct(dataObj) && any(strcmp(param, {'defatt', 'defeph'}))
        % Is it the special case of DEFATT/DEFEPH (read as a struct into dataObj).
        % Do nothing..
      else
        errStr = 'Unrecognized input argument';
        irf.log('critical', errStr);
        error('MATLAB:MMS_SDP_DMGR:INPUT', errStr);
      end
      
      if( ~isempty(DATAC.(param)) )
        % Error, Warning or Notice for replacing the data variable?
        if(~any(strcmp(param,{'hk_101', 'hk_105', 'hk_10e', 'defatt', 'aspoc'})))
          % Only multiple HK/Defatt/aspoc files are allowed for now..
          errStr = ['replacing existing variable (' param ') with new data'];
          irf.log('critical', errStr);
          error('MATLAB:MMS_SDP_DMGR:INPUT', errStr);
        else
          % Warn about multiple files of same type.
          irf.log('warning',['Multiple files for ' param ' detected. Will try to sort them by time.']);
        end
      end
      
      vPfx = sprintf('mms%d_edp_',DATAC.scId);
      
      switch(param)
        case('dce')
          sensors = {'e12','e34','e56'};
          init_param()
          
          % Since v1.0.0 DCE files contain also DCV data
          if ~isfield(dataObj.data, [vPfx, 'dcv_sensor']) || ...
              DATAC.dce.fileVersion.major<1
            if DATAC.dce.fileVersion.major>=1
              irf.log('warning',...
                'DCE major version >= 1 but not combined DCE & DCV data?');
            end
            return
          end
          
          % It appears to be a combined file, extract DCV variables.
          irf.log('notice','Combined DCE & DCV file.');
          
          param = 'dcv';
          sensors = {'v1','v2','v3','v4','v5','v6'};
          init_param()
%          interp_time()
          chk_latched_p()
          %apply_transfer_function()
          v_from_e_and_v()
          chk_bias_guard()
          chk_aspoc_on()
          chk_sweep_on()
          chk_maneuvers()
          chk_sdp_v_vals()
          %e_corr_cmd()
          e_from_asym()
          sensors = {'e12','e34','e56'};
          apply_nom_amp_corr() % AFTER all V values was calculated but before most processing.
          sensors = {'e12','e34'};
          corr_adp_spikes()
          
        case('dcv')
          sensors = {'v1','v2','v3','v4','v5','v6'};
          init_param()
          chk_timeline()
%          interp_time()
          chk_latched_p()
          %apply_transfer_function()
          v_from_e_and_v()
          chk_bias_guard()
          chk_sweep_on()
          chk_maneuvers()
          chk_sdp_v_vals()
          sensors = {'e12','e34','e56'};
          apply_nom_amp_corr() % AFTER all V values was calculated but before most processing.
          sensors = {'e12','e34'};
          corr_adp_spikes()
          
        case('dfg')
          % DFG - Dual fluxgate magn. B-field.
          if(strcmp('v',dataObj.GlobalAttributes.Data_version{1}(1)))
            dfgVerStr = dataObj.GlobalAttributes.Data_version{1}(2:end);
          else
            dfgVerStr = dataObj.GlobalAttributes.Data_version{1}(1:end);
          end
          if( is_version_geq(dfgVerStr,'4.0.0') )
            % Version 4.0.z or later, new variable names conforming to
            % recommended MMS standard.
            vPfx = sprintf('mms%d_dfg_b_dmpa_srvy_l2pre',DATAC.scId);
          else
            % Old versions
            vPfx = sprintf('mms%d_dfg_srvy_l2pre_dmpa',DATAC.scId);
          end
          if( strfind(dataObj.GlobalAttributes.Logical_file_id{1}, 'brst') )
            % Brst segments, change variable names accordingly
            vPfx = strrep(vPfx, 'srvy', 'brst');
          end
          if(isempty(DATAC.(param)))
            % first DFG file
            DATAC.(param).dataObj = dataObj;
            x = getdep(dataObj,vPfx);
            time = x.DEPEND_O.data;
            check_monoton_timeincrease(time, param);
            DATAC.(param).B_dmpa = get_ts(dataObj, vPfx); % TSeries
          else
            % Second DFG file
            DATAC.(param).dataObj2 = dataObj; % Store dataObj.
            x = getdep(dataObj,vPfx);
            time = x.DEPEND_O.data;
            check_monoton_timeincrease(time, param);
            B_dmpa = get_ts(dataObj, vPfx); % TSeries
            % Combine the two into one, based on unique timestamps.
            DATAC.(param).B_dmpa = combine(DATAC.(param).B_dmpa, B_dmpa);
          end
          
        case('hk_101')
          % HK 101, contains sunpulses.
          vPfx = sprintf('mms%d_101_',DATAC.scId);
          %DATAC.(param) = []; % Why was this done? We begin with empty..
          if(isempty(DATAC.(param)))
            % first hk_101 file
            DATAC.(param).dataObj = dataObj;
            x = getdep(dataObj,[vPfx 'cmdexec']);
            DATAC.(param).time = x.DEPEND_O.data;
            check_monoton_timeincrease(DATAC.(param).time, param);
            % Add sunpulse times (TT2000) of last recieved sunpulse.
            DATAC.(param).sunpulse = dataObj.data.([vPfx 'sunpulse']).data;
            % Add sunpulse indicator, real: 0, SC pseudo: 1, CIDP pseudo: 2.
            DATAC.(param).sunssps = dataObj.data.([vPfx 'sunssps']).data;
            % Add CIDP sun period (in microseconds, 0 if sun pulse not real.
            DATAC.(param).iifsunper = dataObj.data.([vPfx 'iifsunper']).data;
          else
            % Second hk_101 file
            DATAC.(param).dataObj2 = dataObj; % Store dataObj.
            x = getdep(dataObj,[vPfx 'cmdexec']);
            time2 = x.DEPEND_O.data;
            check_monoton_timeincrease(time2, param);
            % Combine
            Comb_time = [DATAC.(param).time; time2];
            Comb_sunpulse = [DATAC.(param).sunpulse; dataObj.data.([vPfx 'sunpulse']).data];
            Comb_sunssps = [DATAC.(param).sunssps; dataObj.data.([vPfx 'sunssps']).data];
            Comb_iifsunper = [DATAC.(param).iifsunper; dataObj.data.([vPfx 'iifsunper']).data];
            % Ensure sorted unique timestamps and store the resulting time,
            % sunpulse, sunssps and iisunper.
            [srt_time, srt] = sort(Comb_time);
            [DATAC.(param).time, usrt] = unique(srt_time); 
            DATAC.(param).sunpulse = Comb_sunpulse(srt(usrt));
            DATAC.(param).sunssps = Comb_sunssps(srt(usrt));
            DATAC.(param).iifsunper = Comb_iifsunper(srt(usrt));
          end
          
        case('hk_105')
          % HK 101, contains sunpulses.
          vPfx = sprintf('mms%d_105_',DATAC.scId);
          %DATAC.(param) = [];  % Why was this done? We begin with empty..
          if(isempty(DATAC.(param)))
            % first hk_105 file
            DATAC.(param).dataObj = dataObj;
            x = getdep(dataObj,[vPfx 'sweepstatus']);
            DATAC.(param).time = x.DEPEND_O.data;
            check_monoton_timeincrease(DATAC.(param).time, param);
            % Add sweepstatus which indicates if any of the probes is sweeping
            DATAC.(param).sweepstatus = dataObj.data.([vPfx 'sweepstatus']).data;
          else
            % second hk_105 file
            DATAC.(param).dataObj2 = dataObj;
            x = getdep(dataObj,[vPfx 'sweepstatus']);
            time2 = x.DEPEND_O.data;
            check_monoton_timeincrease(time2, param);
            % Combine
            Comb_time = [DATAC.(param).time; time2];
            Comb_sweepstatus = [DATAC.(param).sweepstatus; dataObj.data.([vPfx 'sweepstatus']).data];
            % Ensure sorted unique timestamps and store the resulting time
            % and sweepstatus.
            [srt_time, srt] = sort(Comb_time);
            [DATAC.(param).time, usrt] = unique(srt_time); 
            DATAC.(param).sweepstatus = Comb_sweepstatus(srt(usrt));
          end
          
        case('hk_10e')
          % HK 10E, contains bias.
          vPfx = sprintf('mms%d_10e_',DATAC.scId);
          hk10eParam = {'dac','ig','og'}; % DAC, InnerGuard & OuterGuard
          if(isempty(DATAC.(param)))
            % First hk_10e file
            DATAC.(param).dataObj = dataObj;
            x = getdep(dataObj,[vPfx 'seqcnt']);
            DATAC.(param).time = x.DEPEND_O.data;
            check_monoton_timeincrease(DATAC.(param).time, param);
            % Go through each probe and store values for easy access,
            % for instance probe 1 dac values as: "DATAC.hk_10e.beb.dac.v1".
            for iParam=1:length(hk10eParam)
              for jj=1:6
                tmpStruct = getv(dataObj,...
                [vPfx 'beb' num2str(jj,'%i') hk10eParam{iParam}]);
                if isempty(tmpStruct)
                  errS = ['cannot get ' vPfx 'beb' num2str(jj,'%i') ...
                    hk10eParam{iParam}]; irf.log('warning',errS), warning(errS);
                else
                  if(isinteger(tmpStruct.data) )
                    irf.log('notice','Old HK 10E, converting to nA or V.');
                    % Convert old format HK10E (ie "version < v0.3.0") to nA or V.
                    switch hk10eParam{iParam}
                      case 'dac'
                        tmpStruct.data = (single(tmpStruct.data)-32768)*25.28*10^-3; % nA
                      case {'og', 'ig'}
                        tmpStruct.data = (single(tmpStruct.data)-32768)*317.5*10^-6; % V
                      otherwise
                          errS ='Something wrong with HK 10E file';
                          irf.log('critical',errS); error(errS);
                    end
                  end
                  DATAC.(param).beb.(hk10eParam{iParam}).(sprintf('v%i',jj)) = ...
                    tmpStruct.data;
                end
              end % for jj=1:6
            end % for iParam=1:length(hk10eParam)
          else
            % Second hk_10e file
            DATAC.(param).dataObj2 = dataObj;
            x = getdep(dataObj,[vPfx 'seqcnt']);
            time2 = x.DEPEND_O.data;
            check_monoton_timeincrease(time2, param);
            % Combine
            Comb_time = [DATAC.(param).time; time2];
            % Ensure sorted unique timestamps and store the resulting time
            % and sweepstatus.
            [srt_time, srt] = sort(Comb_time);
            [DATAC.(param).time, usrt] = unique(srt_time); 
            % Go through each probe and store values for easy access,
            % for instance probe 1 dac values as: "DATAC.hk_10e.beb.dac.v1".
            for iParam=1:length(hk10eParam)
              for jj=1:6
                tmpStruct = getv(dataObj,...
                  [vPfx 'beb' num2str(jj,'%i') hk10eParam{iParam}]);
                if isempty(tmpStruct)
                  errS = ['cannot get ' vPfx 'beb' num2str(jj,'%i') ...
                    hk10eParam{iParam}]; irf.log('warning',errS), warning(errS);
                else
                  % Combine and use the sorted unique indexes (based on
                  % time)
                  if(isinteger(tmpStruct.data) )
                    irf.log('notice','Old HK 10E, converting to nA or V.');
                    % Convert old format HK10E (ie "version < v0.3.0") to nA or V.
                    switch hk10eParam{iParam}
                      case 'dac'
                        tmpStruct.data = (single(tmpStruct.data)-32768)*25.28*10^-3; % nA
                      case {'og', 'ig'}
                        tmpStruct.data = (single(tmpStruct.data)-32768)*317.5*10^-6; % V
                      otherwise
                          errS ='Something wrong with HK 10E file';
                          irf.log('critical',errS); error(errS);
                    end
                  end
                  Comb_data = [DATAC.(param).beb.(hk10eParam{iParam}).(sprintf('v%i',jj)); tmpStruct.data];
                  DATAC.(param).beb.(hk10eParam{iParam}).(sprintf('v%i',jj)) = ...
                    Comb_data(srt(usrt));
                end
              end % for jj=1:6
            end % for iParam=1:length(hk10eParam)
          end
          
        case('defatt')
          % DEFATT, contains Def Attitude (Struct with 'time' and 'zphase' etc)
          % As per e-mail discussion of 2015/04/07, duplicated timestamps can
          % occur in Defatt (per design). If any are found, use the last data
          % point and disregard the first duplicate.
          idxBad = diff(dataObj.time)==0; % Identify first duplicate
          fs = fields(dataObj);
          for idxFs=1:length(fs), dataObj.(fs{idxFs})(idxBad) = []; end
          if(isempty(DATAC.(param)))
            % First defatt file
            DATAC.(param) = dataObj;
            check_monoton_timeincrease(DATAC.(param).time);
          else
            % Second defatt file
            % Combine each field of the structs and run sort & unique on
            % the time
            combined = [DATAC.(param).time; dataObj.time];
            [~, srt] = sort(combined);
            [DATAC.(param).time, usrt] = unique(combined(srt));
            for idxFs=1:length(fs)
              if(~strcmp(fs{idxFs}, 'time'))
                combined = [DATAC.(param).(fs{idxFs}); dataObj.(fs{idxFs})];
                DATAC.(param).(fs{idxFs}) = combined(srt(usrt));
              end
            end
            check_monoton_timeincrease(DATAC.(param).time); % Verify combined defatt
          end
          
        case('defeph')
          % DEFEPH, contains Def Ephemeris (Struct with 'time', 'Pos_X', 'Pos_Y'
          % and 'Pos_Z')
          DATAC.(param) = dataObj;
          check_monoton_timeincrease(DATAC.(param).time);
          
        case('l2a')
          % L2A, contain dce data, spinfits, etc. for L2Pre processing or
          % Fast data/offsets to be used by Brst QL processing.
          DATAC.(param) = [];
          DATAC.(param).dataObj = dataObj;
          % Split up the various parts (spinfits [sdev, e12, e34], dce data
          % [e12, e34, e56], dce bitmask [e12, e34, e56], phase, adc & delta 
          % offsets).
          % Check version number, 1.0.z use new variable names, old 0.1.z did
          % not use.
          if( ~is_version_geq(dataObj.GlobalAttributes.Data_version{1}(2:end),'1.0.0') )
            % Old version, this code segment can be removed when
            % re-processing has occured.
            varPre = ['mms', num2str(DATAC.scId), '_edp_dce'];
            varPre2='_spinfit_'; varPre3='_adc_offset';
            sdpPair = {'e12', 'e34'};
            for iPair=1:numel(sdpPair)
              tmp = dataObj.data.([varPre, varPre2, sdpPair{iPair}]).data(:,2:end);
              % Replace possible FillVal with NaN
              tmp(tmp==getfield(mms_sdp_typecast('spinfits'),'fillval')) = NaN;
              DATAC.(param).spinfits.sfit.(sdpPair{iPair}) = tmp;
              tmp = dataObj.data.([varPre, varPre2, sdpPair{iPair}]).data(:,iPair);
              % Replace possible FillVal with NaN
              tmp(tmp==getfield(mms_sdp_typecast('spinfits'),'fillval')) = NaN;
              DATAC.(param).spinfits.sdev.(sdpPair{iPair}) = tmp;
              tmp = dataObj.data.([varPre, varPre3]).data(:,iPair);
              % Replace possible FillVal with NaN
              tmp(tmp==getfield(mms_sdp_typecast('adc_offset'),'fillval')) = NaN;
              DATAC.(param).adc_off.(sdpPair{iPair}) = tmp;
            end
            x = getdep(dataObj,[varPre, varPre2, sdpPair{iPair}]);
            DATAC.(param).spinfits.time = x.DEPEND_O.data;
            check_monoton_timeincrease(DATAC.(param).spinfits.time, 'L2A spinfits');
            sensors = {'e12', 'e34', 'e56'};
            DATAC.(param).dce = [];
            x = getdep(dataObj,[varPre, '_data']);
            DATAC.(param).dce.time = x.DEPEND_O.data;
            check_monoton_timeincrease(DATAC.(param).dce.time, 'L2A dce');
            for iPair=1:numel(sensors)
              tmp = dataObj.data.([varPre, '_data']).data(:,iPair);
              % Replace possible FillVal with NaN
              tmp(tmp==getfield(mms_sdp_typecast('dce'),'fillval')) = NaN;
              DATAC.(param).dce.(sensors{iPair}).data = tmp;
              tmp = dataObj.data.([varPre, '_bitmask']).data(:,iPair);
              tmp(tmp==getfield(mms_sdp_typecast('bitmask'),'fillval')) = NaN;
              DATAC.(param).dce.(sensors{iPair}).bitmask = tmp;
            end
            tmp = dataObj.data.([varPre, '_phase']).data;
            tmp(tmp==getfield(mms_sdp_typecast('phase'),'fillval')) = NaN;
            DATAC.(param).phase.data = tmp;
            DATAC.(param).delta_off = mms_sdp_dmgr.comp_delta_off(DATAC.(param).spinfits, ...
              DATAC.(param).dce.time, DATAC.(param).dce.(sensors{1}).bitmask, ...
              DATAC.(param).dce.(sensors{2}).bitmask, ...
              DATAC.CONST);
          else
            % New version, new variable names.. This piece of code should be
            % kept after all reprocessing is completed.
            varPre = ['mms', num2str(DATAC.scId), '_edp_'];
            typePos = strfind(dataObj.GlobalAttributes.Data_type{1},'_');
            varSuf = dataObj.GlobalAttributes.Data_type{1}(1:typePos(2)-1);
            sdpPair = {'e12', 'e34'};
            for iPair=1:numel(sdpPair)
              % Spinfits
              tmp1 = dataObj.data.([varPre, 'offsfit_', strrep(sdpPair{iPair},'e','p'),'_', varSuf]).data;
              % Replace possible FillVal with NaN
              tmp1(tmp1==getfield(mms_sdp_typecast('spinfits'),'fillval')) = NaN;
              tmp = dataObj.data.([varPre, 'espin_', strrep(sdpPair{iPair},'e','p'),'_', varSuf]).data;
              % Replace possible FillVal with NaN
              tmp(tmp==getfield(mms_sdp_typecast('spinfits'),'fillval')) = NaN;
              DATAC.(param).spinfits.sfit.(sdpPair{iPair}) = [tmp1, tmp];
              % Sdev
              tmp = dataObj.data.([varPre, 'sdevfit_', strrep(sdpPair{iPair},'e','p'),'_', varSuf]).data;
              % Replace possible FillVal with NaN
              tmp(tmp==getfield(mms_sdp_typecast('spinfits'),'fillval')) = NaN;
              DATAC.(param).spinfits.sdev.(sdpPair{iPair}) = tmp;
              % ADC offset
              tmp = dataObj.data.([varPre, 'adc_offset_', varSuf]).data(:,iPair);
              % Replace possible FillVal with NaN
              tmp(tmp==getfield(mms_sdp_typecast('adc_offset'),'fillval')) = NaN;
              DATAC.(param).adc_off.(sdpPair{iPair}) = tmp;
            end
            x = getdep(dataObj,[varPre, 'espin_', strrep(sdpPair{1},'e','p'),'_', varSuf]);
            DATAC.(param).spinfits.time = x.DEPEND_O.data;
            check_monoton_timeincrease(DATAC.(param).spinfits.time, 'L2A spinfits');
            sensors = {'e12', 'e34', 'e56'};
            DATAC.(param).dce = [];
            x = getdep(dataObj,[varPre, 'dce_', varSuf]);
            DATAC.(param).dce.time = x.DEPEND_O.data;
            check_monoton_timeincrease(DATAC.(param).dce.time, 'L2A dce');
            for iPair=1:numel(sensors)
              % DCE
              tmp = dataObj.data.([varPre, 'dce_', varSuf]).data(:,iPair);
              % Replace possible FillVal with NaN
              tmp(tmp==getfield(mms_sdp_typecast('dce'),'fillval')) = NaN;
              DATAC.(param).dce.(sensors{iPair}).data = tmp;
              % Bitmask
              tmp = dataObj.data.([varPre, 'bitmask_', varSuf]).data(:,iPair);
              tmp(tmp==getfield(mms_sdp_typecast('bitmask'),'fillval')) = NaN;
              DATAC.(param).dce.(sensors{iPair}).bitmask = tmp;
            end
            % Phase
            tmp = dataObj.data.([varPre, 'phase_', varSuf]).data;
            tmp(tmp==getfield(mms_sdp_typecast('phase'),'fillval')) = NaN;
            DATAC.(param).phase.data = tmp;
            % Delta offset
            DATAC.(param).delta_off = mms_sdp_dmgr.comp_delta_off(DATAC.(param).spinfits, ...
              DATAC.(param).dce.time, DATAC.(param).dce.(sensors{1}).bitmask, ...
              DATAC.(param).dce.(sensors{2}).bitmask, ...
              DATAC.CONST);
            % CMDmodel
            if(isfield(dataObj.data, [varPre, 'cmdmodel_', varSuf]))
              % CMDmodel (as of 2016/09/22 only for MMS4 after probe 4
              % failed), to be used in Brst processing.
              tmp = dataObj.data.([varPre, 'cmdmodel_', varSuf]).data;
              tmp(tmp==getfield(mms_sdp_typecast('dce'),'fillval')) = NaN;
              DATAC.(param).CMDModel = tmp;
            end
          end
          
        case('aspoc')
          % ASPOC, have an adverse impact on E-field mesurements.
          vars = fields(dataObj.data);
          for kk=1:length(vars)
            if( ~isempty(strfind(vars{kk},'status')) )
              vPfx = vars{kk}; break
            end
          end
          if( ~isfield(dataObj.data, vPfx) )
            irf.log('warning','Unfamiliar ASPOC file(-s)!!');
            return
          end
          %vPfx = sprintf('mms%d_asp_status',DATAC.scId);
          if(isempty(DATAC.(param)))
            % first hk_101 file
            DATAC.(param).dataObj = dataObj;
            x = getdep(dataObj,vPfx);
            time = x.DEPEND_O.data;
            check_monoton_timeincrease(time, param);
            DATAC.(param).status = get_ts(dataObj, vPfx); % TSeries
          else
            % Second aspoc file
            DATAC.(param).dataObj2 = dataObj; % Store dataObj.
            x = getdep(dataObj,vPfx);
            time = x.DEPEND_O.data;
            check_monoton_timeincrease(time, param);
            status2 = get_ts(dataObj, vPfx); % TSeries
            % Combine the two into one, based on unique timestamps.
            DATAC.(param).status = combine(DATAC.(param).status, status2);
          end

        otherwise
          % Not yet implemented.
          errStr = [' unknown parameter (' param ')'];
          irf.log('critical',errStr);
          error('MATLAB:MMS_SDP_DMGR:INPUT', errStr);
      end
      
      function chk_latched_p()
        % Check that probe values are varying. If there are 3 identical points,
        % or more, after each other mark this as latched data. If it is latched
        % and the data has a value below MMS_CONST.Limit.LOW_DENSITY_SATURATION
        % it will be Bitmasked with Low density saturation otherwise it will be
        % bitmasked with just Probe saturation.
        
        % For each sensor, check each pair, i.e. V_1 & V_2 and E_12.
        for iSen = 1:2:numel(sensors)
          senA = sensors{iSen};  senB = sensors{iSen+1};
          senE = ['e' senA(2) senB(2)]; % E-field sensor
          irf.log('notice', ...
            sprintf('Checking for latched probes on %s, %s and %s.', senA, ...
            senB, senE));
          DATAC.dcv.(senA) = latched_mask(DATAC.dcv.(senA));
          DATAC.dcv.(senB) = latched_mask(DATAC.dcv.(senB));
          DATAC.dce.(senE) = latched_mask(DATAC.dce.(senE));
          % TODO: Check overlapping stuck values, if senA stuck but not senB..
        end
        function sen = latched_mask(sen)
          % Locate data latched for at least 1 second (=1*samplerate).
          idx = irf_latched_idx(sen.data, 1*DATAC.samplerate);
          if ~isempty(idx)
            sen.bitmask(idx) = bitor(sen.bitmask(idx),...
              MMS_CONST.Bitmask.PROBE_SATURATION);
          end
          idx = sen.data<MMS_CONST.Limit.LOW_DENSITY_SATURATION;
          if any(idx)
            sen.bitmask(idx) = bitor(sen.bitmask(idx), ...
              MMS_CONST.Bitmask.LOW_DENSITY_SATURATION);
          end
        end
      end
      
      function chk_timeline()
        % Check that DCE time and DCV time overlap and are measured at the same
        % time (within insturument delays). Throw away datapoint which does not
        % overlap between DCE and DCV.
        if isempty(DATAC.dce)
          irf.log('warning','Empty DCE, cannot proceed')
          return
        end
        % 3.8 us per channel and 7 channels between DCV (probe 1) and DCE (12).
        % A total shift of 26600 ns is therefor to be expected, add this then
        % convert to seconds before comparing times.
        %[~, dce_ind, dcv_ind] = intersect(DATAC.dce.time, DATAC.dcv.time+26001);
        % XXX: The above line is faster, but we cannot be sure it works, as it
        % requires exact mathcing of integer numbers
        % XXX: The code below should work in principle, but id does not
        %[dce_ind, dcv_ind] = irf_find_comm_idx(DATAC.dce.time,...
        %  DATAC.dcv.time+26600,int64(40000)); % tolerate 40 us jitter
        % Highest bitrate is to be 8192 samples/s, which correspond to about
        % 122 us between consecutive measurements. The maximum theoretically
        % allowed jitter would be half of this (60us) for the dcv & dce
        % measurements to be completely unambiguous, use 1/3 margin on this.
        
        %This is a HACK. We just take the nearest time, assuming times in DCE
        %and DCV must be identical.
        tE = DATAC.dce.time; tV = DATAC.dcv.time;
        
        if ~(all(median(diff(tE))==diff(tE)) && all(median(diff(tV))==diff(tV)))
          errStr1 = 'Do not know how to handle gaps';
          irf.log('critical',errStr1), error(errStr1)
        end
        
        % Bring together the DCE and DCV time series
        % NOTE: No gaps allowed below this line
        dt = median(diff(tE));
        if tV(1)>tE(1), tStart = tE(1);
        else, tStart = tE(1) - ceil((tE(1)-tV(1))/dt)*dt;
        end
        if tE(end)>tV(end), tStop = tE(end);
        else, tStop = tE(end) + ceil((tV(end)-tE(end))/dt)*dt;
        end
        nData = (tStop - tStart)/dt + 1;
        newTime = int64((1:nData) - 1)'*dt + tStart;
        [~,idxEonOld,idxEonNew] = intersect(tE,newTime);
        idxEoffNew = setxor(1:length(newTime),idxEonNew);
        tDiffNew = abs(newTime-tV(1)); tDiffOld = abs(newTime(1)-tV);
        if min(min(tDiffNew),min(tDiffOld))==min(tDiffOld)
          iDcvStartOld = find(tDiffOld==min(tDiffOld));
          tDiffNew = abs(newTime-tV(iDcvStartOld));
          iDcvStartNew = find(tDiffNew==min(tDiffNew));
        else
          iDcvStartNew = find(tDiffNew==min(tDiffNew));
          tDiffOld = abs(newTime(iDcvStartNew)-tV);
          iDcvStartOld = find(tDiffOld==min(tDiffOld));
        end
        idxVonOld = (1:length(tV))'-1 +iDcvStartOld;
        idxVonNew = (1:length(tV))'-1 +iDcvStartNew;
        idxVoffNew = setxor(1:length(tV),idxVonNew);
        
        for iSen = 1:2:numel(sensors)  % Loop over e12, e34, e56
          senA = sensors{iSen};  senB = sensors{iSen+1};
          senE = ['e' senA(2) senB(2)]; % E-field sensor
          save_restore('dce',senE,idxEonOld,idxEonNew,idxEoffNew)
          save_restore('dcv',senA,idxVonOld,idxVonNew,idxVoffNew)
          save_restore('dcv',senB,idxVonOld,idxVonNew,idxVoffNew)
        end
        DATAC.dce.time = newTime; DATAC.dcv.time = newTime;
        
        function save_restore(sig,sen,idxOnOld,idxOnNew,idxOffNew)
          % Save old values, expand the variables and restore the old values
          SAVE = DATAC.(sig).(sen);
          DATAC.(sig).(sen).data = NaN(size(newTime),'like',DATAC.(sig).(sen).data);
          DATAC.(sig).(sen).bitmask = zeros(size(newTime),'like',DATAC.(sig).(sen).bitmask);
          DATAC.(sig).(sen).data(idxOnNew)    = SAVE.data(idxOnOld);
          DATAC.(sig).(sen).bitmask(idxOnNew) = SAVE.bitmask(idxOnOld);
          DATAC.(sig).(sen).bitmask(idxOffNew) = MMS_CONST.Bitmask.SIGNAL_OFF;
        end
      end % CHK_TIMELINE
      
      function interp_time()
        % Measurements are not done at same instance but with a delay of
        % 3.8us between each channel. Adjust V[2-6] and E12, E34, E56 with
        % interp1() to align with timestamp of V1 (which is the first
        % channel and for the combined DCE&DCV file this is the time of the
        % Epoch variable).
        % Source used: E-mail from Mark dated 2017/01/11T19:21 CET, and the
        % "Document No. 108328revE".

        % Only Burst mode should be interpolated
        if(DATAC.tmMode == DATAC.CONST.TmMode.brst)
          irf.log('notice', 'Resampling burst measurements to align with first channel ("epoch").');
        else
          irf.log('debug', 'Not in burst mode, not doing resample of measurements to align with first channel ("epoch")');
          return;
        end

        keyboard
        % NOTE THIS FUNCTION IS NOT READY for production, added here as to
        % create test files to see what impact it has on our files. Mainly
        % burst 16'384 Hz may be impacted, but this is TBD. Also "to be
        % checked" is the commissioning data with separate dce and dcv
        % files.

        % Offset between each channel in ADC
        Dt = int64(3.8e3); % 3.8 us expressed in ns (TT2000, int64)
        % V1 is start of nominal Epoch (when combined dce&dcv file)
        % V2 is Dt later (included here, but NaN unless in comm.)
        % V3 is Dt later again (ie 2*Dt)
        % V4 is 3*Dt (NaN unless in comm.)
        % V5 is 4*Dt
        % V6 is 5*Dt (NaN unless in comm.)
        % Dt for one empty "Nap of the ADC"
        % E12 is 7*Dt
        % E34 is 8*Dt
        % E56 is 9*Dt
        tV = DATAC.dcv.time;
        t1 = tV - tV(1);
        %tE = DATAC.dce.time; % Separate time for DCE file?

        % Interpolate each data to align in time with V1, convert int64 and
        % single data into double first than back again after interpolation
        DATAC.dcv.v2.data = single( interp1(double(t1 + 1*Dt), ...
          double(DATAC.dcv.v2.data), ...
          double(t1), 'linear', 'extrap') ); % V2 is nominally NaN
        DATAC.dcv.v3.data = single( interp1(double(t1 + 2*Dt), ...
          double(DATAC.dcv.v3.data), ...
          double(t1), 'linear', 'extrap') );
        DATAC.dcv.v4.data = single( interp1(double(t1 + 3*Dt), ...
          double(DATAC.dcv.v4.data), ...
          double(t1), 'linear', 'extrap') ); % V4 is nominally NaN
        DATAC.dcv.v5.data = single( interp1(double(t1 + 4*Dt), ...
          double(DATAC.dcv.v5.data), ...
          double(t1), 'linear', 'extrap') );
        DATAC.dcv.v6.data = single( interp1(double(t1 + 5*Dt), ...
          double(DATAC.dcv.v6.data), ...
          double(t1), 'linear', 'extrap') ); % V6 is nominally NaN
        DATAC.dce.e12.data = single( interp1(double(t1 + 7*Dt), ...
          double(DATAC.dce.e12.data), ...
          double(t1), 'linear', 'extrap') );
        DATAC.dce.e34.data = single( interp1(double(t1 + 8*Dt), ...
          double(DATAC.dce.e34.data), ...
          double(t1), 'linear', 'extrap') );
        DATAC.dce.e56.data = single( interp1(double(t1 + 9*Dt), ...
          double(DATAC.dce.e56.data), ...
          double(t1), 'linear', 'extrap') );
      end % INTERP_TIME

      function chk_bias_guard()
        % Check that bias/guard setting, found in HK_10E, are nominal. If any
        % are found to be non nominal set bitmask value in both V and E.
        if(~isempty(DATAC.hk_10e))  % is a hk_10e file loaded?
          
          % Get limit struct with primary fields 'ig', 'og' and 'dac',
          % limits stored as TSeries with [max, min] limits and is s/c
          % dependent.
          NomBias = mms_sdp_limit_bias(DATAC.scId);

          irf.log('notice','Checking for non nominal bias settings.');
          for iSen = 1:2:numel(sensors)
            senA = sensors{iSen};  senB = sensors{iSen+1};
            senE = ['e' senA(2) senB(2)]; % E-field sensor
            
            % InnerGuard, OuterGuard (bias voltages), DAC (tracking current)
            hk10eParam = {'ig','og','dac'};
            for iiParam = 1:length(hk10eParam)
              
              % FIXME, proper test of existing fields?
              if( ~isempty(DATAC.hk_10e.beb.(hk10eParam{iiParam}).(senA)) && ...
                  ~isempty(DATAC.hk_10e.beb.(hk10eParam{iiParam}).(senB)) )
                
                % Interpolate HK_10E to match with DCV timestamps, using the
                % previous HK value.
                interp_DCVa = interp1(double(DATAC.hk_10e.time), ...
                  double(DATAC.hk_10e.beb.(hk10eParam{iiParam}).(senA)), ...
                  double(DATAC.dcv.time), 'previous', 'extrap');
                
                interp_DCVb = interp1(double(DATAC.hk_10e.time), ...
                  double(DATAC.hk_10e.beb.(hk10eParam{iiParam}).(senB)), ...
                  double(DATAC.dcv.time), 'previous', 'extrap');
                
                % Interpolate the limits to match the the DCE timestamps as
                % well, using the previous limit.
                interp_MaxMin = interp1(double(NomBias.(hk10eParam{iiParam}).time.epoch),...
                  double(NomBias.(hk10eParam{iiParam}).data), double(DATAC.dce.time),...
                  'previous','extrap');

                % Locate Non Nominal values
                indA = interp_MaxMin(:,2) >= interp_DCVa | interp_DCVa >= interp_MaxMin(:,1);
                indB = interp_MaxMin(:,2) >= interp_DCVb | interp_DCVb >= interp_MaxMin(:,1);
                indE = or(indA,indB); % Either senA or senB => senE non nominal.
                
                if(any(indE))
                  irf.log('notice',['Bad bias on ',...
                    senE,' from ',hk10eParam{iiParam}]);
                  
                  % Add bitmask values to SenA, SenB and SenE for these ind.
                  bits = MMS_CONST.Bitmask.BAD_BIAS;
                  % Add value to the bitmask, leaving other bits untouched.
                  DATAC.dcv.(senA).bitmask(indA) = ...
                    bitor(DATAC.dcv.(senA).bitmask(indA), bits);
                  DATAC.dcv.(senB).bitmask(indB) = ...
                    bitor(DATAC.dcv.(senB).bitmask(indB), bits);
                  DATAC.dce.(senE).bitmask(indE) = ...
                    bitor(DATAC.dce.(senE).bitmask(indE), bits);
                end
              else
                irf.log('Warning',['HK_10E : no proper values for ',...
                  senA,' and ',senB,'.']);
              end % if ~isempty()
            end % for iiParam
          end % for iSen
        else
          irf.log('Warning','No HK_10E file : cannot perform bias/guard check');
        end % if ~isempty(hk_10e)
      end
      
      function chk_maneuvers()
        % Check to see if any maneuvers are planned to occur during the
        % interval we have data. If so, then bitmask it.
        if isempty(DATAC.dce)
          irf.log('warning','Empty DCE, cannot proceed')
          return
        end
        Tint = irf.tint(DATAC.dce.time(1), DATAC.dce.time(end));
        try
          maneuvers = mms_maneuvers(Tint, DATAC.scId);
          scIdStr = sprintf('mms%d', DATAC.scId);
          if(isfield(maneuvers, scIdStr) && ...
              ~isempty(maneuvers.(scIdStr)))
            irf.log('notice', 'Some manuevers found during data interval');
            bits = MMS_CONST.Bitmask.MANEUVERS;
            for ii=1:length(maneuvers.(scIdStr))
              irf.log('notice', ['Bitmasking maneuver: ', ...
                maneuvers.(scIdStr){ii}.start.toUtc, '/', ...
                maneuvers.(scIdStr){ii}.stop.toUtc]);
              ind = (DATAC.dce.time >= maneuvers.(scIdStr){ii}.start.ttns ...
                & DATAC.dce.time <= maneuvers.(scIdStr){ii}.stop.ttns);
              for iSen = 1:2:numel(sensors)
                senA = sensors{iSen};  senB = sensors{iSen+1};
                senE = ['e' senA(2) senB(2)]; % E-field sensor
                DATAC.dcv.(senA).bitmask(ind) = ...
                    bitor(DATAC.dcv.(senA).bitmask(ind), bits);
                DATAC.dcv.(senB).bitmask(ind) = ...
                  bitor(DATAC.dcv.(senB).bitmask(ind), bits);
                DATAC.dce.(senE).bitmask(ind) = ...
                  bitor(DATAC.dce.(senE).bitmask(ind), bits);
              end
            end
          else
            irf.log('debug', 'No maneuvers found during data interval.');
          end
        catch ME
          irf.log('warning', 'Failed to read timeline and bitmask maneuvers.');
          irf.log('warning', ['Got ', ME.identifier, ' with message ', ME.message]);
          return
        end
      end % CHK_MANEUVERS
      
      function chk_sweep_on()
        % Check if sweep is on for all probes
        % if yes, set bit in both V and E bitmask
        
        if isempty(DATAC.dce)
          irf.log('warning','Empty DCE, cannot proceed')
          return
        end
        
        varPref = sprintf('mms%d_sweep_', DATAC.scId);
        if ~isfield(DATAC.dce.dataObj.data,[varPref 'start'])
          errS = ['Did not find ',varPref,'start'];
          irf.log('critical',errS); error(errS)
        end
        
        % Get sweep status and sweep Start/Stop
        % Add extra 0.1 sec to Stop for safety and remove 0.05 sec to Start
        sweepStart = DATAC.dce.dataObj.data.([varPref 'start']).data - 5e7;
        if(DATAC.tmMode == DATAC.CONST.TmMode.slow)
          % Some sweep seems to still be effecting our measurements well
          % after stop time, especially bad in slow mode, see 2016/11/10.
          % (Perhaps intervals with other mode as well but that is still to
          % be determined). Add 0.15 sec to stop time.
          sweepStop = DATAC.dce.dataObj.data.([varPref 'stop']).data + 1.4e8;
        else
          % Add 0.1 seconds to stop.
          sweepStop = DATAC.dce.dataObj.data.([varPref 'stop']).data + 1e8;
        end
        sweepSwept = DATAC.dce.dataObj.data.([varPref 'swept']).data;
        
        if isempty(sweepStart)
          irf.log('warning','No sweep status in DCE file');
          % Alternative approach for finding sweep times using hk_105
          if isempty(DATAC.hk_105)
            irf.log('warning','No HK_105 file loaded: cannot identify sweeps.');
            return
          end
          sweepStatus = logical(DATAC.hk_105.sweepstatus);
          sweepStart = DATAC.hk_105.time([diff(sweepStatus)==1; false]);
          if sweepStatus(1) % First point has sweep ON, start at t(0)-4s
            sweepStart = [DATAC.hk_105.time(1)-int64(4e9) sweepStart];
          end
          sweepStop = DATAC.hk_105.time([false; diff(sweepStatus)==-1]);
          if sweepStatus(end)  % Last point has sweep ON, stop at t(end)+4s
            sweepStop = [sweepStop DATAC.hk_105.time(end)+int64(4e9)];
          end
          if length(sweepStop)~=length(sweepStart)
            % Sanity check, should never be here
            errSt = 'length(sweepStop) != length(sweepStart)!!';
            irf.log('critical',errSt), error(errSt)
          end
          % No info on which probe is swept in hk_105, can be any pair
          sweepSwept = zeros(size(sweepStart));
        end
        
        % For each pair, E_12, E_34, E_56.
        for iSen = 1:2:numel(sensors)
          senA = sensors{iSen};  senB = sensors{iSen+1};
          senE = ['e' senA(2) senB(2)]; % E-field sensor
          irf.log('notice', ['Checking for sweep status on probe pair ', senE]);
          % Locate probe pair senA and senB, SweepSwept = 1 (for pair 12), etc.
          if all(sweepSwept==0), senN = 0; else, senN = str2double(senA(2)); end
          ind = find(sweepSwept==senN);
          sweeping = false(size(DATAC.dce.time)); % First assume no sweeping.
          for ii = 1:length(ind)
            % Each element in ind correspond to a sweep_start and sweep_stop
            % with the requested probe pair. Identify which index these times
            % correspond to in DATAC.dce.time. Each new segment, where
            % (sweep_start<=dce.time<=sweep_stop), is added with 'or' to the
            % previous segments.
            sweeping = or( and(DATAC.dce.time>=sweepStart(ind(ii)), ...
              DATAC.dce.time<=sweepStop(ind(ii))), sweeping);
          end
          if(any(sweeping))
            % Set bitmask on the corresponding pair, leaving the other 16 bits
            % untouched.
            irf.log('notice','Sweeping found, bitmasking it.');
            bits = MMS_CONST.Bitmask.SWEEP_DATA;
            DATAC.dcv.(senA).bitmask(sweeping) = ...
              bitor(DATAC.dcv.(senA).bitmask(sweeping), bits);
            DATAC.dcv.(senB).bitmask(sweeping) = ....
              bitor(DATAC.dcv.(senB).bitmask(sweeping), bits);
            DATAC.dce.(senE).bitmask(sweeping) = ...
              bitor(DATAC.dce.(senE).bitmask(sweeping), bits);
          else
            irf.log('debug',['Did not find any sweep for probe pair ', senE]);
          end % if any(sweeping)
        end % for iSen
      end
      
      function chk_aspoc_on()
        % Check if aspoc is on if yes, set bit in both V and E bitmask
        if isempty(DATAC.dce)
          irf.log('warning','Empty DCE, cannot proceed')
          return
        end
        if(~isempty(DATAC.aspoc))
          % ASPOC file was loaded
          irf.log('notice','Checking for ASPOC ON status.');
          % Interpolate previous status on/off (4th column) and extrapolate
          % to match DCE measurement timestamps
          tmpStatus = DATAC.aspoc.status.data(:,4) > 0;
          ind_ON = logical(interp1(double(DATAC.aspoc.status.time.epoch), ...
            double(tmpStatus), double(DATAC.dce.time),...
            'previous', 'extrap'));
          if(any(ind_ON))
            irf.log('warning','ASPOC was turned on for some period.');
            % Turned on for at least one measurement, set bitmask for all
            % DCV & DCE
            bits = MMS_CONST.Bitmask.ASPOC_RUNNING;
            for iSen = 1:2:numel(sensors)
              senA = sensors{iSen};  senB = sensors{iSen+1};
              senE = ['e' senA(2) senB(2)]; % E-field sensor
              % Add value to the bitmask, leaving other bits untouched.
              DATAC.dcv.(senA).bitmask(ind_ON) = ...
                bitor(DATAC.dcv.(senA).bitmask(ind_ON), bits);
              DATAC.dcv.(senB).bitmask(ind_ON) = ...
                bitor(DATAC.dcv.(senB).bitmask(ind_ON), bits);
              DATAC.dce.(senE).bitmask(ind_ON) = ...
                bitor(DATAC.dce.(senE).bitmask(ind_ON), bits);
            end
          end
        else
          % Else just issue a notice (ASPOC is not to be expected for QL).
          irf.log('notice','Empty ASPOC, cannot set bitmask for it.');
        end
      end % CHK_ASPOC_ON

      function chk_sdp_v_vals()
        % check if probe-to-spacecraft potentials  averaged over one spin for
        % all probes are similar (within TBD %, or V).
        % If not, set bit in both V and E bitmask.
        
        %XXX: Does nothing at the moment
      end
      
      function corr_adp_spikes()
        % correct ADP shadow spikes
        MODEL_THRESHOLD = .01;
        MSK_SHADOW = MMS_CONST.Bitmask.ADP_SHADOW;
        
        Phase = DATAC.phase;
        if isempty(Phase)
          errStr='Bad PHASE input, cannot proceed.';
          irf.log('critical',errStr); error(errStr);
        end
        irf.log('notice','Removing ADP spikes');
        if(DATAC.scId == 4 && all(DATAC.dce.time > EpochTT('2016-06-12T05:28:48.200Z').ttns)) %MMS4 p4 failed
          model = mms_sdp_model_adp_shadow(DATAC.dce, Phase, {'e12', 'p123'});
        else
          model = mms_sdp_model_adp_shadow(DATAC.dce,Phase, {'e12','e34'});
        end
        
        for iSen = 1:min(numel(sensors),2)
          sen = sensors{iSen};
          DATAC.dce.(sen).data = ...
            single(double(DATAC.dce.(sen).data) - model.(sen));
          idx = abs(model.(sen))>MODEL_THRESHOLD;
          DATAC.dce.(sen).bitmask(idx) = ...
            bitor(DATAC.dce.(sen).bitmask(idx), MSK_SHADOW);
        end
      end
      
      function apply_nom_amp_corr()
        % Apply a nominal amplitude correction factor to DCE for p1..6
        % values after cleanup but before any major processing has occured.
        % p1..4 is also rescaled to correct boom length depending on time.
        Blen = mms_sdp_boom_length(DATAC.scId,DATAC.dce.time);
        if length(Blen)==1
          senDist = sensor_dist(Blen.len);
          irf.log('notice',['Adjusting sensor dist to [ '...
            num2str(senDist,'%.2f ') '] meters'])
        else
          boomLen = zeros(length(DATAC.dce.time),4);
          for i=1:length(Blen)
            irf.log('notice',['Adjusting sensor dist to [ '...
              num2str(sensor_dist(Blen(i).len),'%.2f ') '] meters from ' ...
              Blen(i).time.toUtc(1)])
            idx = find(DATAC.dce.time>=Blen(i).time.epoch);
            boomLen(idx,:) = repmat(Blen(i).len,length(idx),1);
          end
          senDist = sensor_dist(boomLen);
        end
        
        factor = MMS_CONST.NominalAmpCorr; NOM_DIST = 120.0;
        for iSen = 1:numel(sensors)
          senE = sensors{iSen};
          nSenA = str2double(senE(2)); nSenB = str2double(senE(3));
          logStr = sprintf(['Applying nominal amplitude correction factor, '...
            '%.2f, to %s'], factor.(senE), senE);
          irf.log('notice',logStr);
          if(strcmp(senE,'e56'))
            distF = 1; % Boom length rescaling for ADP. I.e. only nominal amplitude correction.
          else
            distF = NOM_DIST./(senDist(:,nSenA) + senDist(:,nSenB));
          end
          DATAC.dce.(senE).data = DATAC.dce.(senE).data .* distF * factor.(senE);
        end
        
        function l = sensor_dist(len)
          l = 1.67 + len + .07 + 1.75  + .04; % meters, sc+boom+preAmp+wire+probe
        end
      end
      
      function e_corr_cmd()
        % Correct E for CMD
        Phase = DATAC.phase;
        if isempty(Phase)
          errStr='Bad PHASE input, cannot proceed.';
          irf.log('critical',errStr); error(errStr);
        end
        if(DATAC.tmMode == DATAC.CONST.TmMode.brst)
          % XXX implement something
        else
          irf.log('notice','Correcting E for CMD');
          NOM_BOOM_L = .12; % 120 m
          if 1 % using spin resudual
            SpinModel = mms_sdp_model_spin_residual(DATAC.dce,DATAC.dcv,Phase,...
            {'v1','v2','v3','v4'},DATAC.samplerate);
            DATAC.dce.e12.data = single( double(DATAC.dce.e12.data) - ...
              (SpinModel.v1 - SpinModel.v2)/NOM_BOOM_L );
            DATAC.dce.e34.data = single( double(DATAC.dce.e34.data) - ...
              (SpinModel.v3 - SpinModel.v4)/NOM_BOOM_L );
          else % using CMD
            CmdModel = mms_sdp_model_spin_residual_cmd312(DATAC.dcv,...
              Phase, DATAC.samplerate,'e12');
            DATAC.dce.e12.data = single( ...
              double(DATAC.dce.e12.data) - CmdModel/NOM_BOOM_L );
            CmdModel = mms_sdp_model_spin_residual_cmd312(DATAC.dcv,...
              Phase, DATAC.samplerate,'e34');
            DATAC.dce.e34.data = single( ...
              double(DATAC.dce.e34.data) - CmdModel/NOM_BOOM_L );
          end
        end   
      end
      
      function e_from_asym()
        % Compute E in asymmetric configuration
        
        if(DATAC.scId ~=4 || DATAC.procId == MMS_CONST.SDCProc.scpot), return, end
        
        %PROBE MAGIC
        %MMS4, Probe 4 bias fail, 2016-06-12T05:28:48.2
        TTFail = EpochTT('2016-06-12T05:28:48.200Z');
        indFail = DATAC.dcv.time > TTFail.ttns;
        if ~any(indFail), return, end
        
        senV = 'v4';
        irf.log('notice',['Bad bias on ' senV ' starting at ' TTFail.utc]);
        DATAC.dcv.(senV).bitmask(indFail) = ...
          bitor(DATAC.dcv.(senV).bitmask(indFail), MMS_CONST.Bitmask.BAD_BIAS);
        
        % Compute asymmetric E34
        % Data with no v3 cannot be reconstructed
        sen3_off = bitand(DATAC.dcv.v3.bitmask, MMS_CONST.Bitmask.SIGNAL_OFF);
        DATAC.dce.e34.data(indFail & sen3_off) = NaN; 
        % E34 = (V3 - 0.5*(V1 + V2))/(L/2)
        idx = indFail & ~sen3_off;
        NOM_BOOM_L = .12; % 120 m
        if 0 % The simplest correstion
          DATAC.dce.e34.data(idx) = single((double(DATAC.dcv.v3.data(idx)) - ...
            0.5*(double(DATAC.dcv.v1.data(idx)) +...
            double(DATAC.dcv.v2.data(idx))))/(NOM_BOOM_L/2)); %#ok<UNRCH>
        end
        if 0
          % Correct for spin residual
          Phase = DATAC.phase; %#ok<UNRCH>
          if isempty(Phase)
            errStr='Bad PHASE input, cannot proceed.';
            irf.log('critical',errStr); error(errStr);
          end
          SpinModel = mms_sdp_model_spin_residual(DATAC.dce,DATAC.dcv,Phase,...
            {'v1','v2','v3'},DATAC.samplerate);
          DATAC.dce.e34.data(idx) = single((...
            double(DATAC.dcv.v3.data(idx)) - SpinModel.v3(idx) - ...
            0.5*(double(DATAC.dcv.v1.data(idx))- SpinModel.v1(idx) +...
            double(DATAC.dcv.v2.data(idx))- SpinModel.v2(idx)...
            ))/(NOM_BOOM_L/2));
        end
        if 1
          % Correct for spin residual using model
          Phase = DATAC.phase;
          if isempty(Phase)
            errStr='Bad PHASE input, cannot proceed.';
            irf.log('critical',errStr); error(errStr);
          end
          % FOR BRST SEGMENTS TRY TO USE L2A, if not brst or if no L2a
          % loaded compute CMDModel
          if(DATAC.tmMode == DATAC.CONST.TmMode.brst)
            if(isfield(DATAC.l2a, 'CMDModel'))
              irf.log('notice', 'Using CMD model from L2a file.');
              tmp = irf.ts_scalar(DATAC.l2a.dce.time, DATAC.l2a.CMDModel);
              CmdModel = tmp.resample(EpochTT(DATAC.dce.time(idx)));
              CmdModel = CmdModel.data;
            else
              irf.log('warning','Burst but no L2a (fast) CMD model loaded.');
              CmdModel = mms_sdp_model_spin_residual_cmd312(DATAC.dcv,...
                Phase, DATAC.samplerate);
            end           
            tempE34 = single((...
            double(DATAC.dcv.v3.data(idx)) - ...
            0.5*(double(DATAC.dcv.v1.data(idx)) + ...
            double(DATAC.dcv.v2.data(idx))) - CmdModel)/(NOM_BOOM_L/2));
            if 2*DATAC.samplerate < MMS_CONST.Limit.MERGE_FREQ
              irf.log('warning', ['Sample rate: ', num2str(DATAC.samplerate), ...
                'Hz must be at least twice the merge frequency: ', ...
                num2str(MMS_CONST.Limit.MERGE_FREQ), 'Hz. Will not merge (using only reconstructed).']);
              DATAC.dce.e34.data(idx) = tempE34;
            else
              DATAC.dce.e34.data(idx) = mms_sdp_dmgr.merge_fields(tempE34, DATAC.dce.e34.data(idx), MMS_CONST.Limit.MERGE_FREQ, DATAC.samplerate);
            end
          else
            CmdModel = mms_sdp_model_spin_residual_cmd312(DATAC.dcv, ...
              Phase, DATAC.samplerate);
            DATAC.CMDModel = CmdModel; % Store it, if process is L2A it should be written to file.
            DATAC.dce.e34.data(idx) = single((...
            double(DATAC.dcv.v3.data(idx)) - ...
            0.5*(double(DATAC.dcv.v1.data(idx)) + ...
            double(DATAC.dcv.v2.data(idx))) - CmdModel(idx))/(NOM_BOOM_L/2));
          end
        end
        % Combine the bitmasks, as the new E34 will be affected when
        % either E12 or E34 is sweeping. Other bits are left unaffected.
        e12Sweep = bitand(DATAC.dce.e12.bitmask(idx), MMS_CONST.Bitmask.SWEEP_DATA); % True when e12 sweep
        DATAC.dce.e34.bitmask(idx) = bitor(DATAC.dce.e34.bitmask(idx), e12Sweep);
        DATAC.dce.e34.bitmask(idx) = bitor(DATAC.dce.e34.bitmask(idx), ...
          MMS_CONST.Bitmask.ASYMM_CONF);
      end
      
      function v_from_e_and_v
        % Compute V from E and the other V
        % typical situation is V2 off, V1 on
        % E12[mV/m] = ( V1[V] - V2[V] ) / L[km]
        if isempty(DATAC.dce)
          irf.log('warning','Empty DCE, cannot proceed')
          return
        end
        
        % Nominal boom length used in L1b processor
        NOM_BOOM_L = .12; % 120 m
        NOM_BOOM_L_ADP = .0292; % 29.2m
        
        MSK_OFF = MMS_CONST.Bitmask.SIGNAL_OFF;
        for iSen = 1:2:numel(sensors)
          if iSen == 5, NOM_BOOM_L = NOM_BOOM_L_ADP; end
          senA = sensors{iSen}; senB = sensors{iSen+1};
          senE = ['e' senA(2) senB(2)]; % E-field sensor
          senA_off = bitand(DATAC.dcv.(senA).bitmask, MSK_OFF);
          senB_off = bitand(DATAC.dcv.(senB).bitmask, MSK_OFF);
          senE_off = bitand(DATAC.dce.(senE).bitmask, MSK_OFF);
          idxOneSig = xor(senA_off,senB_off);
          iVA = idxOneSig & ~senA_off;
          if any(iVA)
            irf.log('notice',...
              sprintf('Computing %s from %s and %s for %d data points',...
              senB,senA,senE,sum(iVA)))
            DATAC.dcv.(senB).data(iVA) = single(...
              double(DATAC.dcv.(senA).data(iVA)) - ...
              NOM_BOOM_L*double(DATAC.dce.(senE).data(iVA)));
          end
          iVB = idxOneSig & ~senB_off;
          if any(iVB)
            irf.log('notice',...
              sprintf('Computing %s from %s and %s for %d data points',...
              senA,senB,senE,sum(iVA)))
            DATAC.dcv.(senA).data(iVB) = single(...
              double(DATAC.dcv.(senB).data(iVB)) + ...
              NOM_BOOM_L*double(DATAC.dce.(senE).data(iVB)));
          end
          % For comissioning data we will have all DCE/DCV, verify consistency.
          idxBoth = and(and(~senA_off, ~senB_off), ~senE_off);
          if any(idxBoth)
            irf.log('notice',...
              sprintf('Verifying %s = (%s - %s)/NominalLength for %d points',...
              senE, senA, senB, sum(idxBoth)));
            remaining = abs(NOM_BOOM_L*DATAC.dce.(senE).data(idxBoth) - ...
              DATAC.dcv.(senA).data(idxBoth) + ...
              DATAC.dcv.(senB).data(idxBoth));
            if(any(remaining>MMS_CONST.Limit.DCE_DCV_DISCREPANCY))
              irf.log('warning',...
                'Datapoints show a discrepancy between DCE and DCV!');
              % FIXME: Bitmasking them or exit with Error?
            end
          end % if any(idxBoth)
        end % for iSen
      end
      
      function init_param
        DATAC.(param) = [];
        if(isfield(dataObj.data, [vPfx 'samplerate_' param]))
          if ~all(diff(dataObj.data.([vPfx 'samplerate_' param]).data)==0)
            err_str = ...
              'MMS_SDP_DMGR changing sampling rate not yet implemented.';
            irf.log('critical', err_str); error(err_str);
          end
        elseif(isfield(dataObj.data,[vPfx 'samplerate_dce']))
          % Combined DCE & DCV file have only "[vPfx samplerate_dce]".
          if ~all(diff(dataObj.data.([vPfx 'samplerate_dce']).data)==0)
            err_str = ...
              'MMS_SDP_DMGR changing sampling rate not yet implemented.';
            irf.log('critical', err_str); error(err_str);
          end
        else
          irf.log('warning','No samplerate variable present in DATAOBJ.');
        end
        DATAC.(param).dataObj = dataObj;
        fileVersion = DATAC.(param).dataObj.GlobalAttributes.Data_version{:};
        % Skip the intial "v" and split it into [major minor revision].
        fileVersion = str2double(strsplit(fileVersion(2:end),'.'));
        DATAC.(param).fileVersion = struct('major', fileVersion(1), 'minor',...
          fileVersion(2), 'revision', fileVersion(3));
        % Make sure it is not too old to work properly.
        if DATAC.(param).fileVersion.major < MMS_CONST.MinFileVer
          err_str = sprintf('File too old: major version %d < %d',...
            DATAC.(param).fileVersion.major, MMS_CONST.MinFileVer);
          irf.log('critical',err_str), error(err_str); %#ok<SPERR>
        end
        if(dataObj.data.([vPfx param '_sensor']).nrec==0)
          err_str='Empty sensor data. Possibly started processing too early..';
          irf.log('critical',err_str); error(err_str);
        end
        x = getdep(dataObj,[vPfx param '_sensor']);
        DATAC.(param).time = x.DEPEND_O.data;
        check_monoton_timeincrease(DATAC.(param).time, param);
        sensorData = dataObj.data.([vPfx param '_sensor']).data;
        if isempty(sensors), return, end
        probeEnabled = resample_probe_enable(sensors);
        %probeEnabled = are_probes_enabled;
        columnIn = 1;
        for iSen=1:numel(sensors)
          if(size(sensorData,2)==numel(sensors))
            DATAC.(param).(sensors{iSen}) = struct(...
              'data',sensorData(:,iSen), ...
              'bitmask',zeros(size(sensorData(:,iSen)),...
              getfield(mms_sdp_typecast('bitmask'),'matlab')));
          else
            irf.log('warning','Trying to identify enabled/disabled probes.');
            DATAC.(param).(sensors{iSen}) = struct(...
              'data', NaN(size(sensorData,1),1,'like',sensorData), ...
              'bitmask', zeros(size(sensorData,1),1,...
              getfield(mms_sdp_typecast('bitmask'),'matlab')));
            if(~all(probeEnabled(:,iSen)==0))
              % One of the not completely disabled probes, store columnIn from
              % sensorData in corresponding DATAC location. FIXME when allowing
              % for switching enabled/disabled probes.
              DATAC.(param).(sensors{iSen}).data = sensorData(:,columnIn);
              columnIn = columnIn+1;
            end
          end
          %Set disabled bit
          idxDisabled = probeEnabled(:,iSen)==0;
          if(any(idxDisabled>0))
            irf.log('notcie', ['Probe ',sensors{iSen}, ' disabled for ',...
              num2str(sum(idxDisabled)),' points. Bitmask them and set to NaN.']);
            DATAC.(param).(sensors{iSen}).bitmask(idxDisabled) = ...
              bitor(DATAC.(param).(sensors{iSen}).bitmask(idxDisabled), ...
              MMS_CONST.Bitmask.SIGNAL_OFF);
            DATAC.(param).(sensors{iSen}).data(idxDisabled,:) = NaN;
          end
        end
      end
      
%       function res = are_probes_enabled
%         % Use FILLVAL of each sensor to determine if probes are enabled or not.
%         % Returns logical of size correspondig to sensor.
%         sensorData = dataObj.data.([vPfx param '_sensor']).data;
%         FILLVAL = getfillval(dataObj, [vPfx, param, '_sensor']);
%         if( ~ischar(FILLVAL) )
%           % Return 'true' for all data not equal to specified FILLVAL
%           res = (sensorData ~= FILLVAL);
%         else
%           errStr = 'Unable to get FILLVAL.';
%           irf.log('critical',errStr); error(errStr);
%         end
%       end
      
      function res = resample_probe_enable(fields)
        % resample probe_enabled data to E-field cadense
        probe = fields{1};
        flag = get_variable(dataObj,[vPfx probe '_enable']);
        dtSampling = median(diff(flag.DEPEND_0.data));
        switch DATAC.tmMode
          case MMS_CONST.TmMode.slow, dtNominal = [2.0, 3.0, 4.0, 5.0, 8, 12, 16, 20, 160]; % seconds, (160 from old 1 Hz data)
          case MMS_CONST.TmMode.fast, dtNominal = [2.0, 3.0, 4.0, 5.0];
	  case MMS_CONST.TmMode.brst, dtNominal = [0.6256, 0.625, 0.3128, 0.229, 0.1564, 0.0763, 0.0782, 0.0391, 0.01953];
          case MMS_CONST.TmMode.comm, dtNominal = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0, 4.0 5.0, 8.0, 12.0, 16.0, 20.0];
          otherwise
            errS = 'Unrecognized tmMode';
            irf.log('critical',errS), error(errS)
        end
        dtNominal = int64(dtNominal*1e9); % convert to ns
        
        flagOK = false;
        for i=1:numel(dtNominal)
          if dtSampling > dtNominal(i)*.95 && dtSampling < dtNominal(i)*1.05
            dtSampling = dtNominal(i); flagOK = true; break
          end
        end
        if ~flagOK
          errS = ['bad sampling for ' vPfx probe '_enable'];
          irf.log('critical',errS), error(errS)
        end
        enabled.time = flag.DEPEND_0.data;
        nData = numel(enabled.time);
        enabled.data = zeros(nData,numel(fields));
        enabled.data(:,1) = flag.data;
        for iF=2:numel(fields)
          probe = fields{iF};
          flag = getv(dataObj,[vPfx probe '_enable']);
          if isempty(flag)
            errS = ['cannot get ' vPfx probe '_enable'];
            irf.log('critical',errS), error(errS)
          elseif numel(flag.data) == 0
            irf.log('warning',...
              ['Empty variable ' vPfx probe '_enable. Assuming disabled.']);
            flag.data = zeros(nData,1);
          elseif numel(flag.data) ~= nData
            errS = ['bad size for ' vPfx probe '_enable'];
            irf.log('critical',errS), error(errS)
          end
          enabled.data(:,iF) = flag.data;
        end
        newT = DATAC.(param).time;
        % Default to zero - probe disabled
        res = zeros(numel(newT), numel(fields));
        if all(diff(enabled.data))==0
          ii = newT>(enabled.time(1)-dtSampling) & newT<=(enabled.time(end)+dtSampling);
          for iF=1:numel(fields)
            res(ii,iF) = enabled.data(1,iF);
          end
        else
          % TODO: implements some smart logic.
          errS = 'MMS_SDP_DMGR enabling/disabling probes not yet implemented.';
          irf.log('critical', errS); error(errS);
        end
      end
      
      function check_monoton_timeincrease(time, dataType)
        % Short function for verifying Time is increasing.
        if(any(diff(time)<=0))
          err_str = ['Time is NOT increasing for the datatype ', dataType];
          irf.log('critical', err_str);
          error('MATLAB:MMS_SDP_DMGR:TIME:NONMONOTON', err_str);
        end
      end
    end
    
    function res = get.adc_off(DATAC)
      if ~isempty(DATAC.adc_off), res = DATAC.adc_off; return, end
      if isempty(DATAC.dce)
        errStr='Bad DCE input, cannot proceed.';
        irf.log('critical',errStr); error(errStr);
      end
      res = mms_sdp_adc_off(DATAC.dce.time,DATAC.spinfits);
      DATAC.adc_off = res;
    end
    
    function res = get.dce_xyz_dsl(DATAC)
      if ~isempty(DATAC.dce_xyz_dsl), res = DATAC.dce_xyz_dsl; return, end
      
      Dce = DATAC.dce;
      if isempty(Dce)
        errStr='Bad DCE input, cannot proceed.';
        irf.log('critical',errStr); error(errStr);
      end
      Phase = DATAC.phase;
      if isempty(Phase)
        errStr='Bad PHASE input, cannot proceed.';
        irf.log('critical',errStr); error(errStr);
      end
      Adc_off = DATAC.adc_off;
      if isempty(Adc_off)
        errStr='Bad ADC_OFF input, cannot proceed.';
        irf.log('critical',errStr); error(errStr);
      end
      deltaOff = DATAC.delta_off;
      if mms_is_error(deltaOff)
        errStr='Bad DELTA_OFF input, cannot proceed.';
        irf.log('critical',errStr); error(errStr);
      end
      % FIX Brst ql/l2pre using Fast L2a spinfits!
      if( isfield(DATAC.l2a, 'spinfits') )
        deltaTime = DATAC.l2a.spinfits.time;
      else
        deltaTime = DATAC.spinfits.time;
      end
      DeltaOff = irf.ts_vec_xy(deltaTime, [real(deltaOff), imag(deltaOff)]);
      DeltaOffR = DeltaOff.resample(EpochTT(DATAC.dce.time));
      sdpProbes = fieldnames(Adc_off); % default {'e12', 'e34'}
      Etmp = struct('e12',Dce.e12.data,'e34',Dce.e34.data);
      for iProbe=1:numel(sdpProbes)
        % Remove ADC offset
        Etmp.(sdpProbes{iProbe}) = ...
          Etmp.(sdpProbes{iProbe}) - Adc_off.(sdpProbes{iProbe});
      end
      MMS_CONST = DATAC.CONST;
      bitmask = mms_sdp_typecast('bitmask',bitor(Dce.e12.bitmask,Dce.e34.bitmask));
      Etmp.e12 = mask_bits(Etmp.e12, bitmask, MMS_CONST.Bitmask.SWEEP_DATA);
      Etmp.e34 = mask_bits(Etmp.e34, bitmask, MMS_CONST.Bitmask.SWEEP_DATA);   
      dE = mms_sdp_despin(Etmp.e12, Etmp.e34, Phase.data,...
        DeltaOffR.data(:,1) + DeltaOffR.data(:,2)*1j);
      % Get DSL offsets
      offs = mms_sdp_get_offset(DATAC.scId, DATAC.procId, Dce.time);
      DATAC.calFile = offs.calFile; % Store name of cal file used.
      dE(:,1) = dE(:,1) - offs.ex; % Remove sunward
      dE(:,2) = dE(:,2) - offs.ey; % and duskward offsets
      % Note, positve E56 correspond to minus DSL-Z direction.
      DATAC.dce_xyz_dsl = struct('time',Dce.time,'data',[dE -Dce.e56.data],...
        'bitmask',bitmask);
      res = DATAC.dce_xyz_dsl;
    end
    
    function res = get.delta_off(DATAC)
      if ~isempty(DATAC.delta_off), res = DATAC.delta_off; return, end
      
      % QL brst should use delta offset from Fast L2A file
      if(DATAC.tmMode == DATAC.CONST.TmMode.brst)
        if(isfield(DATAC.l2a,'delta_off'))
          res = DATAC.l2a.delta_off; return;
        else
          irf.log('warning','Burst but no L2a (fast) delta offsets loaded.');
        end
      end

      % Otherwise compute it..
      Spinfits = DATAC.spinfits;
      if isempty(Spinfits)
        errStr='Bad SPINFITS input, cannot proceed.';
        irf.log('critical',errStr); error(errStr);
      end
      MMS_CONST = DATAC.CONST;
      DATAC.delta_off = mms_sdp_dmgr.comp_delta_off(Spinfits,...
        DATAC.dce.time, DATAC.dce.e12.bitmask, DATAC.dce.e34.bitmask,...
        MMS_CONST);
      
      if DATAC.delta_off == MMS_CONST.Error
        irf.log('warning','Delta offset could not be computed.');
      end
      res = DATAC.delta_off;
    end
    
    function res = get.phase(DATAC)
      if ~isempty(DATAC.phase), res = DATAC.phase; return, end
      
      Dce = DATAC.dce;
      if isempty(Dce)
        errStr='Bad DCE input, cannot proceed.';
        irf.log('critical',errStr); error(errStr);
      end
      
      % Begin trying to use DEFATT
      Defatt = DATAC.defatt;
      if(~isempty(Defatt))
        % Defatt was set, use it for phase.
        phaseTS = mms_defatt_phase(Defatt, Dce.time);
        dcephase_flag = zeros(size(phaseTS.data)); % FIXME BETTER FLAG & BITMASKING!
        DATAC.phase = struct('data', phaseTS.data, 'bitmask', dcephase_flag);
      else
        % No defatt was set, try to use HK 101 sunpulses for phase
        Hk_101 = DATAC.hk_101;
        if(isempty(Hk_101))
          errStr='No DEFATT and bad HK_101 input, cannot proceed.';
          irf.log('critical',errStr); error(errStr);
        end
        [dcephase, dcephase_flag] = mms_sdp_phase_2(Hk_101, Dce.time);
        DATAC.phase = struct('data',dcephase,'bitmask',dcephase_flag);
      end
      res = DATAC.phase;
    end
    
    function res = get.probe2sc_pot(DATAC)
      if ~isempty(DATAC.probe2sc_pot), res = DATAC.probe2sc_pot; return, end
      
      Dcv = DATAC.dcv;
      if isempty(Dcv)
        errStr='Bad DCV input, cannot proceed.';
        irf.log('critical',errStr); error(errStr);
      end
      
      DATAC.probe2sc_pot = ...
        mms_sdp_dmgr.comp_probe2sc_pot(Dcv,DATAC.CONST);
      res = DATAC.probe2sc_pot;
    end
    
    function res = get.sc_pot(DATAC)
      if ~isempty(DATAC.sc_pot), res = DATAC.sc_pot; return, end
      
      Probe2sc_pot = DATAC.probe2sc_pot;
      if isempty(Probe2sc_pot)
        errStr='Bad PROBE2SC_POT input, cannot proceed.';
        irf.log('critical',errStr); error(errStr);
      end
      
      % Get probe to plasma potential (offs.p2p) for this time interval
      offs = mms_sdp_get_offset(DATAC.scId, DATAC.procId, Probe2sc_pot.time);
      DATAC.calFile = offs.calFile; % Store name of cal file used.
      scPot = - Probe2sc_pot.data(:) .* offs.shortening(:) + offs.p2p;
      
      DATAC.sc_pot = struct('time',Probe2sc_pot.time,'data',scPot,...
        'bitmask',Probe2sc_pot.bitmask);
      res = DATAC.sc_pot;
    end
    
    function res = get.spinfits(DATAC)
      if ~isempty(DATAC.spinfits), res = DATAC.spinfits; return, end
      
      Dce = DATAC.dce;
      if isempty(Dce)
        errStr='Bad DCE input, cannot proceed.';
        irf.log('critical',errStr); error(errStr);
      end
      Phase = DATAC.phase;
      if isempty(Phase)
        errStr='Bad PHASE input, cannot proceed.';
        irf.log('critical',errStr); error(errStr);
      end
      sampleRate = DATAC.samplerate;
      if isempty(sampleRate)
        errStr='Bad SAMPLERATE input, cannot proceed.';
        irf.log('critical',errStr); error(errStr);
      end
      
      MMS_CONST = DATAC.CONST;
      
      % Some default settings
      MAX_IT = 3;      % Maximum of iterations to run fit
      N_TERMS = 3;     % Number of terms to fit, Y = A + B*sin(wt) + C*cos(wt) +..., must be odd.
      MIN_FRAC = 0.20; % Minumum fraction of points required for one fit (minPts = minFraction * fitInterv [s] * samplerate [smpl/s] )
      FIT_EVERY = 5*10^9;   % Fit every X nanoseconds.
      FIT_INTERV = double(MMS_CONST.Limit.SPINFIT_INTERV); % Fit over X nanoseconds interval.
      
      sdpPair = {'e12', 'e34'}; time = [];
      Sfit = struct(sdpPair{1}, [],sdpPair{2}, []);
      Sdev = struct(sdpPair{1}, [],sdpPair{2}, []);
      Iter = struct(sdpPair{1}, [],sdpPair{2}, []);
      NBad = struct(sdpPair{1}, [],sdpPair{2}, []);
      
      % Calculate minumum number of points req. for one fit covering fitInterv
      minPts = MIN_FRAC * sampleRate * FIT_INTERV/10^9; % "/10^9" as fitInterv is in [ns].
      
      % Calculate first timestamp of spinfits to be after start of dce time
      % and evenly divisable with fitEvery.
      % I.e. if fitEvery = 5 s, then spinfit timestamps would be like
      % [00.00.00; 00.00.05; 00.00.10; 00.00.15;] etc.
      % For this one must rely on spdfbreakdowntt2000 as the TT2000 (int64)
      % includes things like leap seconds.
      t1 = spdfbreakdowntt2000(Dce.time(1)); % Start time in format [YYYY MM DD HH MM ss mm uu nn]
      % Evenly divisable timestamp with fitEvery after t1, in ns.
      t2 = ceil((t1(6)*10^9+t1(7)*10^6+t1(8)*10^3+t1(9))/FIT_EVERY)*FIT_EVERY;
      % Note; spdfcomputett2000 can handle any column greater than expected,
      % ie "62 seconds" are re-calculated to "1 minute and 2 sec".
      t3.sec = floor(t2/10^9);
      t3.ms  = floor((t2-t3.sec*10^9)/10^6);
      t3.us  = floor((t2-t3.sec*10^9-t3.ms*10^6)/10^3);
      t3.ns  = floor(t2-t3.sec*10^9-t3.ms*10^6-t3.us*10^3);
      % Compute what TT2000 time that corresponds to, using spdfcomputeTT2000.
      t0 = spdfcomputett2000([t1(1) t1(2) t1(3) t1(4) t1(5) t3.sec t3.ms t3.us t3.ns]);
      
      if( (Dce.time(1)<=t0) && (t0<=Dce.time(end)))
        for iPair=1:numel(sdpPair)
          sigE = sdpPair{iPair};
          probePhaseRad = unwrap(Phase.data*pi/180) - MMS_CONST.Phaseshift.(sigE);
          dataIn = Dce.(sigE).data;
          bits = bitor(MMS_CONST.Bitmask.SIGNAL_OFF,MMS_CONST.Bitmask.SWEEP_DATA);
          dataIn = mask_bits(dataIn, Dce.(sigE).bitmask, bits);
          idxBad = isnan(dataIn); dataIn(idxBad) = [];
          timeIn = Dce.time; timeIn(idxBad) = [];
          probePhaseRad(idxBad) = [];
          
          % It is possible that the time (default 5 sec evenly) differs
          % between the probe pairs as they do not sweep at the same time.
          % Store the previous "time" and find common timestamps if they
          % do differ.
          if(iPair>1), prevTime = time; end
          % Call mms_spinfit_m, .m interface file for the mex compiled file
          % XXX FIXME: converting time here to double reduces the precision.
          % It would be best if the function accepted time as seconds from
          % the start of the day or t0
          [time, Sfit.(sigE), Sdev.(sdpPair{iPair}), Iter.(sigE), NBad.(sigE)] = ...
            mms_spinfit_m(MAX_IT, minPts, N_TERMS, double(timeIn), double(dataIn), ...
            probePhaseRad, FIT_EVERY, FIT_INTERV, t0);
          % For the second pair (or more) compare the spinfits timestamps
          % and discard any times only fitted to one of the probe pairs
          % (due to removing sweeping) so their dimensions match.
          if(iPair>1 && size(prevTime,1) ~= size(time,1))
            [idxPrev, idxTime] = irf_find_comm_idx(prevTime, time);
            % Keep only the overlapping time in the newly computed spinfits
            time = time(idxTime);
            Sfit.(sigE) = Sfit.(sigE)(idxTime,:);
            Sdev.(sigE) = Sdev.(sigE)(idxTime);
            Iter.(sigE) = Iter.(sigE)(idxTime);
            NBad.(sigE) = NBad.(sigE)(idxTime);
            % Keep only the overlappong times in the previously computed
            % spinfits
            for iPrev=iPair-1:-1:1
              sigPrev = sdpPair{iPrev};
              Sfit.(sigPrev) = Sfit.(sigPrev)(idxPrev,:);
              Sdev.(sigPrev) = Sdev.(sigPrev)(idxPrev);
              Iter.(sigPrev) = Iter.(sigPrev)(idxPrev);
              NBad.(sigPrev) = NBad.(sigPrev)(idxPrev);
            end
          end
          % Change to single
          Sfit.(sigE) = single(Sfit.(sigE));
          Sdev.(sigE) = single(Sdev.(sigE));
          Iter.(sigE) = single(Iter.(sigE));
          NBad.(sigE) = single(NBad.(sigE));
        end
      else
        warnStr = sprintf(['Too short time series:'...
          ' no data cover first spinfit timestamp (t0=%i)'],t0);
        irf.log('warning', warnStr);
      end
      % Store output.
      DATAC.spinfits = struct('time', int64(time), 'sfit', Sfit,...
        'sdev', Sdev, 'iter', Iter, 'nBad', NBad);
      
      res = DATAC.spinfits;
    end
    
    function reset_prop(DATAC,propName,newVal)
      if nargin<3, newVal = []; end
      if isprop(DATAC,propName)
        irf.log('warning',['Resetting :' propName])
        DATAC.(propName) = newVal;
      else
        errS = ['No such property :' propName];
        irf.log('critical',errS), error(errS)
      end
    end
    
    function process_l2a_to_l2pre(DATAC, MMS_CONST)
      if(DATAC.procId == MMS_CONST.SDCProc.l2a || DATAC.procId == MMS_CONST.SDCProc.l2pre)
        if(DATAC.tmMode ~= MMS_CONST.TmMode.brst)
          % Do full L2Pre processing on L2A Fast/slow data.
          %% FIXME: MOVE TO PROPER SUBFUNCTIONS.
          DATAC.l2a.adp = DATAC.l2a.dce.e56.data;
          % DESPIN, using L2A data (offsets, phase etc).
          sdpProbes = fieldnames(DATAC.l2a.adc_off); % default {'e12', 'e34'}
          Etmp = struct('e12',DATAC.l2a.dce.e12.data,'e34',DATAC.l2a.dce.e34.data);
          for iProbe=1:numel(sdpProbes)
            % Remove ADC offset
            Etmp.(sdpProbes{iProbe}) = ...
              Etmp.(sdpProbes{iProbe}) - DATAC.l2a.adc_off.(sdpProbes{iProbe});
          end
          MMS_CONST = DATAC.CONST;
          bitmask = mms_sdp_typecast('bitmask',bitor(DATAC.l2a.dce.e12.bitmask,DATAC.l2a.dce.e34.bitmask));
          Etmp.e12 = mask_bits(Etmp.e12, bitmask, MMS_CONST.Bitmask.SWEEP_DATA);
          Etmp.e34 = mask_bits(Etmp.e34, bitmask, MMS_CONST.Bitmask.SWEEP_DATA);
          DeltaOff = irf.ts_vec_xy(DATAC.l2a.spinfits.time, [real(DATAC.l2a.delta_off), imag(DATAC.l2a.delta_off)]);
          DeltaOffR = DeltaOff.resample(EpochTT(DATAC.l2a.dce.time));
          dE = mms_sdp_despin(Etmp.e12, Etmp.e34, DATAC.l2a.phase.data, DeltaOffR.data(:,1) + DeltaOffR.data(:,2)*1j);
          offs = mms_sdp_get_offset(DATAC.scId, DATAC.procId, DATAC.l2a.dce.time);
          DATAC.calFile = offs.calFile; % Store name of cal file used.
          dE(:,1) = dE(:,1) - offs.ex; % Remove sunward
          dE(:,2) = dE(:,2) - offs.ey; % and duskward offsets
          % Compute DCE Z from E.B = 0, if >10 deg and if abs(B_z)> 1 nT.
          B_tmp = DATAC.dfg.B_dmpa;
          B_tmp.data((abs(B_tmp.z.data) <= 1), :) = NaN;
          dEz = irf_edb(TSeries(EpochTT(DATAC.l2a.dce.time),dE,'vec_xy'), B_tmp, 10, 'E.B=0');
          DATAC.l2a.dsl = struct('data',[dEz.data],...
            'bitmask',bitmask);

        else
          % L1b data combined with L2A fast to be processed for L2Pre
          % brst.
          DATAC.l2a.adp = -DATAC.dce.e56.data; % Note: minus (L1b dce e56) to align with DSL Z
          % Compute values from DCE and store in intermediate l2a
          % position
          DATAC.l2a.dce.time = DATAC.dce.time;
          DATAC.l2a.phase = DATAC.phase;
          DATAC.l2a.adc_off = DATAC.adc_off;
          sdpProbes = fieldnames(DATAC.l2a.adc_off); % default {'e12', 'e34'}
          Etmp = struct('e12',DATAC.dce.e12.data,'e34',DATAC.dce.e34.data);
          for iProbe=1:numel(sdpProbes)
            % Remove ADC offset
            Etmp.(sdpProbes{iProbe}) = ...
              Etmp.(sdpProbes{iProbe}) - DATAC.adc_off.(sdpProbes{iProbe});
          end
          MMS_CONST = DATAC.CONST;
          bitmask = mms_sdp_typecast('bitmask',bitor(DATAC.dce.e12.bitmask,DATAC.dce.e34.bitmask));
          Etmp.e12 = mask_bits(Etmp.e12, bitmask, MMS_CONST.Bitmask.SWEEP_DATA);
          Etmp.e34 = mask_bits(Etmp.e34, bitmask, MMS_CONST.Bitmask.SWEEP_DATA);
          DeltaOff = irf.ts_vec_xy(DATAC.l2a.spinfits.time, [real(DATAC.l2a.delta_off), imag(DATAC.l2a.delta_off)]);
          DeltaOffR = DeltaOff.resample(EpochTT(DATAC.l2a.dce.time));
          dE = mms_sdp_despin(Etmp.e12, Etmp.e34, DATAC.phase.data, DeltaOffR.data(:,1) + DeltaOffR.data(:,2)*1j);
          offs = mms_sdp_get_offset(DATAC.scId, DATAC.procId, DATAC.dce.time);
          DATAC.calFile = offs.calFile; % Store name of cal file used.
          dE(:,1) = dE(:,1) - offs.ex; % Remove sunward
          dE(:,2) = dE(:,2) - offs.ey; % and duskward offsets
          % Compute DCE Z from E.B = 0, if >10 deg and if abs(B_z)> 1 nT.
          B_tmp = DATAC.dfg.B_dmpa;
          B_tmp.data((abs(B_tmp.z.data) <= 1), :) = NaN;
          dEz = irf_edb(TSeries(EpochTT(DATAC.dce.time),dE,'vec_xy'), B_tmp, 10, 'E.B=0');
          DATAC.l2a.dsl = struct('data',[dEz.data],...
            'bitmask',bitmask);
        end
      end
    end % process_l2a_to_l2pre
    
  end % public Methods
  methods (Static)
    function delta_off = comp_delta_off(Spinfits, ...
        bitmaskTime, bitmaskP12, bitmaskP34, MMS_CONST)
      %COMP_DELTA_OFF compute delta offsets
      %
      % delta = MMS_SDP_DMGR.COMP_DELTA_OFF(Spinfits,...
      %              bitmaskTime,bitmaskP12,bitmaskP34,MMS_CONST)
      delta_off = MMS_CONST.Error;
      bits = MMS_CONST.Bitmask.ASPOC_RUNNING;
      % ASPOC ON mask
      mask = bitand(bitmaskP12,bits) > 0;
      % XXX this will not be nescesary when we will have a reliable ASPOC bit
      mask = mask | (bitand(bitmaskP34,bits) > 0);
      
      % Resample bitmask
      spinSize = MMS_CONST.Limit.SPINFIT_INTERV;
      mskAsponOnSpin = zeros(size(Spinfits.time));
      intsON = find_on();
      for idxInt=1:size(intsON,1)
        mskAsponOnSpin((Spinfits.time> bitmaskTime(intsON(1,1))-spinSize/2) & ...
          (Spinfits.time<= bitmaskTime(intsON(1,2))+spinSize/2)) = 1;
      end
      Delta_p12_p34 = Spinfits.sfit.e12(:,2:3) - Spinfits.sfit.e34(:,2:3);
      mskAsponOnSpin = logical(mskAsponOnSpin);
      if all(mskAsponOnSpin) || ~any(mskAsponOnSpin)
        Delta_p12_p34_smooth = new_delta_off(Delta_p12_p34);
      else
        DelTmp = Delta_p12_p34; DelTmp(mskAsponOnSpin) = NaN;
        Delta_p12_p34_smooth = new_delta_off(DelTmp); % aspoc off
        DelTmp = Delta_p12_p34; DelTmp(~mskAsponOnSpin) = NaN;
        Delta_p12_p34_smooth_Tmp = new_delta_off(DelTmp); % aspoc on
        Delta_p12_p34_smooth(mskAsponOnSpin,:) =...
          Delta_p12_p34_smooth_Tmp(mskAsponOnSpin,:);
      end

      delta_off = Delta_p12_p34_smooth(:,1) + Delta_p12_p34_smooth(:,2)*1j;
             
      function out = new_delta_off(inp)
        %%
        flagStd = false;
        WIN_SIZE = 119; % number of spinfits (5 sec) in a window, must be odd
        winW2 = fix(WIN_SIZE/2);
        if winW2==WIN_SIZE/2, error('winSize must be an odd number'), end
        idx = (1:(winW2*2+1))-1;
        % XXX TODO: replace chebwin() with tabulated data so that we will
        % not need signal processing toolbox
        %win = chebwin(WIN_SIZE); sWin = sum(win);
	    % use chebwin_talbe (tabular values)
	    win = chebwin_table(WIN_SIZE); sWin = sum(win);
        
        [nData, nCol]=size(inp);
        if nCol~=2, error('expecting INP with 2 columns'), end
        data = [NaN(winW2,nCol); inp ; NaN(winW2,nCol)];
        out = NaN(nData, nCol);
        
        %% reove spikes
        one_iter(); %plot(out), hold on
        NR = 6; NITER = 3;
        for iter = 1:NITER
          res = inp - out; % residual
          mad = median(abs(res)); mad = repmat(mad',[1 nData])';
          inpTmp = inp; inpTmp(abs(res)>=NR*mad) = NaN;
          data(winW2+(1:nData),:) = inpTmp;
          one_iter();
        end
        
        function one_iter
          %%
          for i = 1:nData
            tt = data(i+idx,:);
            idxNan = isnan(tt(:,1)) | isnan(tt(:,2));
            if all(idxNan), continue, end
            if flagStd
              STD_THR = 1.5;
              s = std(tt(~idxNan,:)); m = mean(tt(~idxNan,:));
              tt(abs(tt(:,1)-m(1))>s(1)*STD_THR,1) = NaN;
              tt(abs(tt(:,2)-m(2))>s(2)*STD_THR,2) = NaN;
              idxNan = isnan(tt(:,1)) | isnan(tt(:,2));
            end
            if any(idxNan)
              idxNNan = ~idxNan;
              sWinNaN = sum(win(idxNNan));
              out(i,:) = sum(tt(idxNNan,:).*[win(idxNNan) win(idxNNan)])/sWinNaN;
            else
              out(i,:) = sum(tt.*[win win])/sWin;
            end
          end
          %%
        end
        
        function w = chebwin_table(L)
          % Tablular values for L=119 only.
          if(L==119)
            chebwinTable = [0.000411163910123; 0.000515459556632; 0.000830350406912; ...
              0.001264681979928; 0.001848061944924; 0.002614529601119; ...
              0.003602761081911; 0.004856213587647; 0.006423197633619; ...
              0.008356866721957; 0.010715114563889; 0.013560370999078; ...
              0.016959289081214; 0.020982317415235; 0.025703153725169; ...
              0.031198077777868; 0.037545164154235; 0.044823377905387; ...
              0.053111558809152; 0.062487302698499; 0.073025751108949; ...
              0.084798303223711; 0.097871266717503; 0.112304466546049; ...
              0.128149832931883; 0.145449991694327; 0.164236881602301; ...
              0.184530424538520; 0.206337274905416; 0.229649674838268; ...
              0.254444441390954; 0.280682110907137; 0.308306264279142; ...
              0.337243054735453; 0.367400957205817; 0.398670755223349; ...
              0.430925777781370; 0.464022394626360; 0.497800774205781; ...
              0.532085903978596; 0.566688868123050; 0.601408372933180; ...
              0.636032505479081; 0.670340706514983; 0.704105934252385; ...
              0.737096991568960; 0.769080985589309; 0.799825885435373; ...
              0.829103141378020; 0.856690326691513; 0.882373762271193; ...
              0.905951083559756; 0.927233709561502; 0.946049174714102; ...
              0.962243286124095; 0.975682071130225; 0.986253483296290; ...
              0.993868838696220; 0.998463958668262];
          else
            errStr='Unexpected window size in hard coded filter table.';
            irf.log('critical', errStr); error(errStr);
          end
          w = [chebwinTable; 1; flipud(chebwinTable)]; 
        end
      end % DEL_MY
      function ints = find_on()
        % find intervals when mask is set
        idxJump = find(diff(mask)~=0);
        ints = []; iStop = [];
        for idxJmp=1:length(idxJump)+1
          if isempty(iStop), iStart = 1; else, iStart = iStop + 1; end
          if idxJmp==length(idxJump)+1, iStop = length(mask); 
          else, iStop = idxJump(idxJmp); 
          end
          if ~mask(iStart), continue, end
          ints = [ ints; iStart iStop]; %#ok<AGROW>
        end 
      end % FIND_ON
    end % COMP_DELTA_OFF
    
    function probe2sc_pot = comp_probe2sc_pot(Dcv,MMS_CONST)
      % COMP_PROBE2SC_POT  compute probe to SC potential
      %
      % p2sc_pot = MMS_SDP_DMGR.COMP_PROBE2SC_POT(Dcv, MMS_CONST)
      % Blank sweeps
      sweepBit = MMS_CONST.Bitmask.SWEEP_DATA;
      Dcv.v1.data = mask_bits(Dcv.v1.data, Dcv.v1.bitmask, sweepBit);
      Dcv.v2.data = mask_bits(Dcv.v2.data, Dcv.v2.bitmask, sweepBit);
      Dcv.v3.data = mask_bits(Dcv.v3.data, Dcv.v3.bitmask, sweepBit);
      Dcv.v4.data = mask_bits(Dcv.v4.data, Dcv.v4.bitmask, sweepBit);
      
      % Probe 4 bias failure
      badBias = MMS_CONST.Bitmask.BAD_BIAS;
      Dcv.v3.data = mask_bits(Dcv.v3.data, Dcv.v4.bitmask, badBias);
      Dcv.v4.data = mask_bits(Dcv.v4.data, Dcv.v4.bitmask, badBias);
      
      % Compute average of all spin plane probes, ignoring data identified
      % as bad (NaN).
      avPot = irf.nanmean([Dcv.v1.data, Dcv.v2.data, Dcv.v3.data, Dcv.v4.data], 2);
      
      % Combine bitmask so that bit 0 = 0 (either four or two probes was
      % used), bit 0 = 1 (either one probe or no probe (if no probe => NaN
      % output in data). The other bits are a bitor comination of those
      % probes that were used (i.e. bitmask = 2 (dec), would mean at least
      % one probe that was used).
      badBits = false(length(Dcv.v1.bitmask), 4);
      badBits(:,1) = isnan(Dcv.v1.data); badBits(:,2) = isnan(Dcv.v2.data);
      badBits(:,3) = isnan(Dcv.v3.data); badBits(:,4) = isnan(Dcv.v4.data);
      % Start with bit 0
      bitmask = uint16(sum(badBits,2)>=3); % Three or more badBits on each row.
      % Extract probe bitmask, excluding the lowest bit (signal off)
      bits = intmax(class(bitmask)) - MMS_CONST.Bitmask.SIGNAL_OFF;
      vBit = zeros(length(Dcv.v1.bitmask),4,'like',MMS_CONST.Bitmask.SIGNAL_OFF);
      vBit(:,1) = bitand(Dcv.v1.bitmask, bits);
      vBit(:,2) = bitand(Dcv.v2.bitmask, bits);
      vBit(:,3) = bitand(Dcv.v3.bitmask, bits);
      vBit(:,4) = bitand(Dcv.v4.bitmask, bits);
      % Combine bitmasks with bitor of times when probe was used to derive
      % mean. (I.e. not marked by badBits).
      for ii=1:4
        bitmask(~badBits(:,ii)) = bitor(bitmask(~badBits(:,ii)), vBit(~badBits(:,ii),ii));
      end
      
      probe2sc_pot = struct('time',Dcv.time,'data',avPot,'bitmask',bitmask);
    end

    function res = merge_fields(lowfield,highfield,cfreq,fSample)
      % Merge two fields at a specific frequency.
      % Input:  lowfield - field used at frequencies below cfreq
      %         highfield - field used at frequencies above cfreq
      %         cfreq - fields are merged at this frequency
      %         fSample - sampling frequency of lowfield and highfield

      % Convert fields to double precision
      lowfield = double(lowfield);
      highfield = double(highfield);
      % Check sampling frequency
      fSample = round(fSample);
      if rem(fSample,2)
          fSample = fSample-1; % Make sure fSample is even (so N is odd)
      end
      N = fSample-1; % FIR filter order (must be odd)
      beta = 6; % approx. stop band attenuation.
      fcut = double(cfreq/(fSample/2));
      % Compute Kaiser window used in FIR
      kwindow = double(besseli(0,beta*sqrt(1-(((0:N-1)-(N-1)/2)/((N-1)/2)).^2))/besseli(0,beta));
      % Design the N'th order lowpass FIR filter
      ff = [0;fcut;fcut;1];
      aa = [1;1;0;0];
      W = double(ones(length(ff)/2,1));                 
      ff=ff(:)/2; 
      L=(N-1)/2;
      m=(0:L);
      k=m';
      k=k(2:length(k));
      b0=0;  
      b=zeros(size(k));
      for s=1:2:length(ff)
        m=(aa(s+1)-aa(s))/(ff(s+1)-ff(s));
        b1=aa(s)-m*ff(s);
        % Compute sinc functions
        sinc2kfs = sin(2*pi*k*ff(s))./(2*pi*k*ff(s));
        sinc2kfs(isnan(sinc2kfs)) = 1;
        sinc2kfs1 = sin(2*pi*k*ff(s+1))./(2*pi*k*ff(s+1));
        sinc2kfs1(isnan(sinc2kfs1)) = 1;
        b0 = b0 + (b1*(ff(s+1)-ff(s)) + m/2*(ff(s+1)*ff(s+1)-ff(s)*ff(s)))...
          * abs(W((s+1)/2)^2) ;
        b = b+(m/(4*pi*pi)*(cos(2*pi*k*ff(s+1))-cos(2*pi*k*ff(s)))./(k.*k))...
          * abs(W((s+1)/2)^2);
        b = b + (ff(s+1)*(m*ff(s+1)+b1)*sinc2kfs1 ...
          - ff(s)*(m*ff(s)+b1)*sinc2kfs) * abs(W((s+1)/2)^2);
      end
      b=[b0; b];
      a=(W(1)^2)*4*b;
      a(1) = a(1)/2;
      hh=[a(L+1:-1:2)/2; a(1); a(2:L+1)/2].';
      LoP = hh.*kwindow;
      LoP = LoP/sum(LoP); 
      
      % Apply filter to lowfield and highfield
      nfact = max(1,3*(N-1)); 
      a = 1.0;
      a = a(:);
      LoP = LoP(:);
      a(N,1)=0;
      rows = [1:N-1, 2:N-1, 1:N-2];
      cols = [ones(1,N-1), 2:N-1, 2:N-1];
      vals = [1+a(2), a(3:N).', ones(1,N-2), -ones(1,N-2)];
      zi = sparse(rows,cols,vals) \ (LoP(2:N) - LoP(1)*a(2:N));
      % Apply lowpass filter to lowfield
      xt = -lowfield(nfact+1:-1:2) + 2*lowfield(1);
      [~,zo] = filter(LoP,a(:), xt, zi(:)*xt(1));
      [yc2,zo] = filter(LoP,a(:), lowfield, zo);
      xt = -lowfield(end-1:-1:end-nfact) + 2*lowfield(end);
      yc3 = filter(LoP,a(:), xt, zo);   
      [~,zo] = filter(LoP,a(:), yc3(end:-1:1), zi(:)*yc3(end));
      yc5 = filter(LoP,a(:), yc2(end:-1:1), zo);
      lowfieldfilt = yc5(end:-1:1); 
      % Apply lowpass filter to highfield
      xt = -highfield(nfact+1:-1:2) + 2*highfield(1);
      [~,zo] = filter(LoP,a(:), xt, zi(:)*xt(1));
      [yc2,zo] = filter(LoP,a(:), highfield, zo);
      xt = -highfield(end-1:-1:end-nfact) + 2*highfield(end);
      yc3 = filter(LoP,a(:), xt, zo);  
      [~,zo] = filter(LoP,a(:), yc3(end:-1:1), zi(:)*yc3(end));
      yc5 = filter(LoP,a(:), yc2(end:-1:1), zo);
      highfieldfilt = yc5(end:-1:1);
      % Remove signals below cfreq (high pass filter)
      highfieldfilt = highfield - highfieldfilt;
      % Merge measured and reconstructed fields
      res = single(lowfieldfilt+highfieldfilt);
    end
    
  end % static methods
  
end

