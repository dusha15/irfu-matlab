function lp_sweep_gui(action)
%LP_SWEEP_GUI interactively work with sweeps
%
% LP_SWEEP
%
% You can access the results from the figures data 'userdata'.
% data=get(gcf,'userdata');ud=data.ud
%
% ud.I - current
% ud.U - voltage
% ud.dUdI - resistance
% ud.... - many other parameters
%

persistent message;
if isempty(message), % run only the first time during the session
    message='You can anytime access all the results from get(gcf,''userdata'').';
    disp(message);
end
if      nargin == 0, action='initialize';end
switch action,
    case 'initialize'
        %% default values
        ud=struct();
        ud.U_string='-20 : 50';
        ud.R_sun=1; % distance in AU
        ud.UV_factor=1;
        % probe
        ud.probe_type='spherical';
        ud.probe_radius=4; % in cm
        ud.probe_length=4; % in cm
        ud.probe_total_vs_sunlit_area=4;
        ud.probe_total_area=(ud.probe_radius*.01)^2*4*pi;
        % s/c
        ud.sc_radius=1; % [m]
        ud.flag_use_sc=0; % 0-not use, 1- use sc
        ud.sc_probe_refpot_as_fraction_of_scpot=0.25; % reference potential at probe
        % plasma
        ud.m_amu1=1;
        ud.m_amu2=16;
        ud.m2=0; % relative fraction of 2nd species
        ud.n=0; % [cc]
        ud.Ti=0;
        ud.Te=0;
        ud.V_SC=0;
        
        %% initialize figure
        set(0,'defaultLineLineWidth', 1.5);
        fn=figure(63);
        clf reset;
        clear h;
        set(fn,'color','white'); % white background for figures (default is grey)
        set(gcf,'PaperUnits','centimeters')
        set(gcf,'defaultAxesFontSize',14);
        set(gcf,'defaultTextFontSize',14);
        set(gcf,'defaultAxesFontUnits','pixels');
        set(gcf,'defaultTextFontUnits','pixels');
        xSize = 12; ySize = 12;
        xLeft = (21-xSize)/2; yTop = (30-ySize)/2;
        set(gcf,'PaperPosition',[xLeft yTop xSize ySize])
        set(gcf,'Position',[100 300 xSize*50 ySize*50])
        set(gcf,'paperpositionmode','auto') % to get the same printing as on screen
        clear xSize sLeft ySize yTop
        %        set(fn,    'windowbuttondownfcn', 'irf_minvar_gui(''ax'')');zoom off;
        ud.h(1)=axes('position',[0.1 0.25 0.5 0.3]); % [x y dx dy]
        ud.h(2)=axes('position',[0.1 0.65 0.5 0.3]); % [x y dx dy]
        ud.h(3)=axes('position',[0.1 0.0 0.5 0.13]); % [x y dx dy]
        linkaxes(ud.h(1:2),'x');
        axis(ud.h(3),'off');
        ud.ht=text(0,1,'','parent',ud.h(3));
        set(fn,'userdata',ud);
        
        %% initialize probe menu
        hp = uipanel('Title','Probe','FontSize',12,'BackgroundColor',[1 0.95 1],'Position',[.7 .0 .3 .45]);
        inp.update = uicontrol('Parent',hp,'String','Update','Position',[2 10 60 30],'Callback','lp_sweep_gui(''update'')');
        inp.reset = uicontrol('Parent',hp,'String','Reset','Position',[70 10 60 30],'callback', 'lp_sweep_gui(''initialize'')');
        inp.U_text = uicontrol('Parent',hp,'String','U [V]','Position',[2 40 60 30]);
        inp.U_value = uicontrol('Parent',hp,'String',ud.U_string,'style','edit','Position',[70 40 100 30],'backgroundcolor','white');
        inp.Rsun_text = uicontrol('Parent',hp,'String','Rsun [AU]','Position',[2 70 60 30]);
        inp.Rsun_value = uicontrol('Parent',hp,'String',num2str(ud.R_sun),'style','edit','Position',[70 70 100 30],'backgroundcolor','white');
        inp.UV_factor_text = uicontrol('Parent',hp,'String','UV factor','Position',[2 100 60 30]);
        inp.UV_factor_value = uicontrol('Parent',hp,'String',num2str(ud.UV_factor),'style','edit','Position',[70 100 100 30],'backgroundcolor','white');
        inp.probe_radius_text = uicontrol('Parent',hp,'String','probe radius [cm]','Position',[2 130 90 30]);
        inp.probe_radius_value = uicontrol('Parent',hp,'String',num2str(ud.probe_radius),'style','edit','Position',[100 130 70 30],'backgroundcolor','white');
        inp.probe_length_text = uicontrol('Parent',hp,'String','probe length [cm]','Position',[2 160 90 30]);
        inp.probe_length_value = uicontrol('Parent',hp,'String','','style','text','Position',[100 160 70 30],'backgroundcolor','white');
        inp.probe_total_vs_sunlit_area_text = uicontrol('Parent',hp,'String','total/sunlit area','Position',[2 190 90 30]);
        inp.probe_total_vs_sunlit_area_value = uicontrol('Parent',hp,'String',num2str(ud.probe_total_vs_sunlit_area),'style','text','Position',[100 190 70 30],'backgroundcolor','white');
        inp.probe_type = uicontrol('Parent',hp,'String','spherical probe|cylindrical probe|specify probe area','style','popup','Position',[2 220 150 30],'backgroundcolor','white','Callback', @setprobetype);
        
        %% initialize s/c menu
        hsc = uipanel('Title','Spacecraft','FontSize',12,'BackgroundColor',[.95 1 1],'Position',[.7 .5 .3 .2]);
        inp.sc_radius_text = uicontrol('Parent',hsc,'String','s/c efficient radius [m]','Position',[0 0 120 25]);
        inp.sc_radius_value = uicontrol('Parent',hsc,'String',num2str(ud.sc_radius),'style','edit','Position',[120 0 50 25],'backgroundcolor','white');
        inp.sc_probe_refpot_as_fraction_of_scpot_text = uicontrol('Parent',hsc,'String','Probe refpot/scpot','Position',[0 25 120 25]);
        inp.sc_probe_refpot_as_fraction_of_scpot_value = uicontrol('Parent',hsc,'String',num2str(ud.sc_probe_refpot_as_fraction_of_scpot),'style','edit','Position',[120 25 50 25],'backgroundcolor','white');
        inp.flag_sc = uicontrol('Parent',hsc,'style','radio','String','Model spacecraft','Value',0,'Position',[0 75 120 25]);
        inp.sc_example = uicontrol('Parent',hsc,'String','Example spacecraft|Cluster|Solar Orbiter|THEMIS','style','popup','Position',[0 50 150 25],'backgroundcolor','white','Callback', @setscexample);
        
        %% initialize plasma menu
        hpl = uipanel('Title','Plasma','FontSize',12,'BackgroundColor',[1 1 .95],'Position',[.7 .75 .3 .2]);
        inp.n = uicontrol('Parent',hpl,'String','Ne [cc]','Position',[0 0 50 25]);
        inp.n_value = uicontrol('Parent',hpl,'String',num2str(ud.n),'style','edit','Position',[50 0 50 25],'backgroundcolor','white');
        inp.Te = uicontrol('Parent',hpl,'String','Te [eV]','Position',[0 25 50 25]);
        inp.Te_value = uicontrol('Parent',hpl,'String',num2str(ud.Te),'style','edit','Position',[50 25 50 25],'backgroundcolor','white');
        inp.Ti = uicontrol('Parent',hpl,'String','Ti [eV]','Position',[0 50 50 25]);
        inp.Ti_value = uicontrol('Parent',hpl,'String',num2str(ud.Ti),'style','edit','Position',[50 50 50 25],'backgroundcolor','white');
        
        ud.inp=inp;
        set(gcf,'userdata',ud);
        %
        lp_sweep_gui('update');
    case 'update'
        disp('Updating');
        ud=get(gcf,'userdata');
        %% get input parameters
        inp=ud.inp;
        ud.U=eval(get(inp.U_value,'string'));
        ud.UV_factor=str2double(get(inp.UV_factor_value,'string'));
        ud.R_sun=str2double(get(inp.Rsun_value,'string'));
        ud.probe_radius=str2double(get(inp.probe_radius_value,'string'));
        ud.n=eval(get(inp.n_value,'string'));
        ud.Te=eval(get(inp.Te_value,'string'));
        ud.Ti=eval(get(inp.Ti_value,'string'));
        
        %% calculate IU curves
        Upot=ud.U(:);
        switch ud.probe_type
            case 'spherical'
                probe_cross_section=pi*(ud.probe_radius*.01)^2;
                probe_total_area=4*probe_cross_section;
                probe_type=1;
            case 'cylindrical'
                probe_cross_section=2*ud.probe_radius*ud.probe_length*0.01^2;
                probe_total_area=pi*probe_cross_section;
                probe_type=2;
                ud.probe_length=str2double(get(inp.probe_length_value,'string'));
            case 'arbitrary'
                probe_type=1;
        end
        J_probe=lp_probecurrent(probe_type,probe_cross_section,probe_total_area,Upot,ud.R_sun,ud.UV_factor,ud.m_amu1,ud.m_amu2,ud.m2,ud.n*1e6,ud.Ti,ud.Te,ud.V_SC);
        dUdI=gradient(Upot,J_probe);
        ud.I=J_probe;
        ud.dUdI=dUdI;
        % if scflag read in sc parameters
        ud.flag_use_sc=get(inp.flag_sc,'Value');
        if ud.flag_use_sc,
            ud.sc_probe_refpot_as_fraction_of_scpot=str2double(get(inp.sc_probe_refpot_as_fraction_of_scpot_value,'string'));
            ud.sc_radius=str2double(get(inp.sc_radius_value,'string'));
        end
        % if scflag then calculate s/c IU curve
        if ud.flag_use_sc,
            J_sc=lp_probecurrent(probe_type,pi*ud.sc_radius^2,4*pi*ud.sc_radius^2,Upot,ud.R_sun,ud.UV_factor,ud.m_amu1,ud.m_amu2,ud.m2,ud.n*1e6,ud.Ti,ud.Te,ud.V_SC);
            % probe current neglecting reference potential
            J_probe=lp_probecurrent(probe_type,probe_cross_section,probe_total_area,Upot,ud.R_sun,ud.UV_factor,ud.m_amu1,ud.m_amu2,ud.m2,ud.n*1e6,ud.Ti,ud.Te,ud.V_SC);
            ud.I_sc=J_sc;
            ud.dUdI_sc=gradient(Upot,J_sc);
        end
        % if scflag calculate probe to sc IU curve
        if ud.flag_use_sc,
            Iprobe=min(J_probe):.01*(max(J_probe)-min(J_probe)):max(J_probe);
            Iprobe=Iprobe(:);
            % plasma current with UV factor zero
            J_probe_plasma=lp_probecurrent(probe_type,probe_cross_section,probe_total_area,Upot,ud.R_sun,0.00000000,ud.m_amu1,ud.m_amu2,ud.m2,ud.n*1e6,ud.Ti,ud.Te,ud.V_SC);
            Isat=-Iprobe;
            Usatsweep=interp1(J_sc,Upot,Isat); % floating potential of sc during sweep
            Uproberefsweep=ud.sc_probe_refpot_as_fraction_of_scpot*Usatsweep; % reference potential around probe
            Uprobe2plasma=zeros(size(Upot)); % initialize
            for ii=1:numel(Iprobe),
                % photoelectron current with plasma current zero
                J_probe_photo=lp_probecurrent(probe_type,probe_cross_section,probe_total_area,Upot-Uproberefsweep(ii),ud.R_sun,ud.UV_factor,ud.m_amu1,ud.m_amu2,ud.m2,0.000000000,ud.Ti,ud.Te,ud.V_SC);
                J_probe=J_probe_plasma+J_probe_photo;
                Uprobe2plasma(ii)=interp1(J_probe,Upot,Iprobe(ii));
            end
            
            Uprobe2sc=Uprobe2plasma-Usatsweep;
            Uprobe2refpot=Uprobe2plasma-Uproberefsweep;
            dUdI_probe2plasma=gradient(Uprobe2plasma,Iprobe);
            dUdI_probe2sc=gradient(Uprobe2sc,Iprobe);
            dUdI_probe2refpot=gradient(Uprobe2refpot,Iprobe);
            dUdI=dUdI_probe2refpot;
            Upot=Uprobe2refpot;
            J_probe=Iprobe;
        end
        
        %% plot IU curve
        info_txt='';
        h=ud.h;
        plot(h(1),Upot,J_probe*1e6,'b');
        grid(h(1),'on');
        xlabel(h(1),'U [V]');
        ylabel(h(1),'I [\mu A]');
        if ud.flag_use_sc,
            hold(h(1),'on');
            plot(h(1),Uprobe2plasma,Iprobe*1e6,'r','linewidth',1.5);
            plot(h(1),Uprobe2sc,Iprobe*1e6,'k','linewidth',1.5);
            hold(h(1),'off');
        end
        if ud.flag_use_sc,
            irf_legend(h(1),'    probe to plasma IU',[0.98 0.03],'color','r');
            irf_legend(h(1),' probe to reference IU',[0.98 0.13],'color','b');
            irf_legend(h(1),'probe to spacecraft IU',[0.98 0.23],'color','k');
        end
        
        plot(h(2),Upot,dUdI);
        grid(h(2),'on');xlabel(h(2),'U [V]');
        ylabel(h(2),'dU/dI [\Omega]');
        if ud.flag_use_sc,
            hold(h(2),'on');
            plot(h(2),Uprobe2plasma,dUdI_probe2plasma,'r','linewidth',1.5);
            plot(h(2),Uprobe2sc,dUdI_probe2sc,'k','linewidth',1.5);
            hold(h(2),'off');
        end
        axis(h(2),'tight');
        Rmin = min(dUdI); % minimum resistance
        disp(['Rmin=' num2str(Rmin,3) ' Ohm']);
        if ud.flag_use_sc,
            info_txt=[info_txt '\newline probe to plasma Rmin=' num2str(min(dUdI_probe2plasma),3) ' Ohm'];
            info_txt=[info_txt '\newline probe to reference Rmin=' num2str(min(dUdI),3) ' Ohm'];
            info_txt=[info_txt '\newline probe to spacecraft Rmin=' num2str(min(dUdI_probe2sc),3) ' Ohm'];
        else
            info_txt=[info_txt '\newline Rmin=' num2str(Rmin,3) ' Ohm'];
        end
        if min(J_probe)<0 && max(J_probe)>0,
            Ufloat=interp1(J_probe,Upot,0); % floating potential
            ii=isfinite(Upot);Rfloat=interp1(Upot(ii),dUdI(ii),Ufloat);
            info_txt=[info_txt '\newline Ufloat=' num2str(Ufloat,3) 'V, R at Ufloat R= ' num2str(Rfloat,3) ' Ohm'];
            disp(['Ufloat=' num2str(Ufloat,3) ' V, R at Ufloat R=' num2str(Rfloat,3) ' Ohm']);
        end
        set(h(2),'yscale','log')
        
        
        axis(h(3),'off');
        set(ud.ht,'string',info_txt);
        set(gcf,'userdata',ud);
end
end

function setprobetype(hObj,event) %#ok<INUSD>
% Called when user activates popup menu of minvar method
val = get(hObj,'Value');
data=get(gcf,'userdata');
if val ==1
    data.probe_type='spherical';
    set(data.inp.probe_length_value,'style','text','string','');
elseif val == 2
    data.probe_type='cylindrical';
    set(data.inp.probe_length_value,'style','edit','string',num2str(data.probe_length));
elseif val == 3
    data.probe_type='arbitrary';
end
set(gcf,'userdata',data);
end

function setscexample(hObj,event) %#ok<INUSD>
% Called when user activates popup menu of minvar method
val = get(hObj,'Value');
data=get(gcf,'userdata');
if val ==1 % do nothing, shows in menu 'Example spacecraft'
elseif val ==2, % Cluster
    data.probe_type='spherical';
    set(data.inp.probe_type,'Value',1);
    set(data.inp.probe_length_value,'style','text','string','');
    set(data.inp.probe_radius_value,'string','4');
    set(data.inp.sc_radius_value,'string','1.1');
    set(data.inp.sc_probe_refpot_as_fraction_of_scpot_value,'string','.2');
    set(data.inp.Rsun_value,'string','1');
    set(data.inp.probe_total_vs_sunlit_area_value,'string','4');
    data.probe_total_vs_sunlit_area=4;
    set(data.inp.n_value,'string','1');
    set(data.inp.Te_value,'string','100');
    set(data.inp.Ti_value,'string','500');
elseif val == 3 % Solar Orbiter
    data.probe_type='cylindrical';
    set(data.inp.probe_type,'Value',2);
    set(data.inp.sc_radius_value,'string','1.2');
    set(data.inp.probe_radius_value,'string','1.15');
    set(data.inp.probe_length_value,'style','edit','string','500');
    set(data.inp.sc_radius_value,'string','1.1');
    set(data.inp.probe_total_vs_sunlit_area_value,'string',num2str(pi,4));
    data.probe_total_vs_sunlit_area=pi;
    set(data.inp.Rsun_value,'string','0.28');
    set(data.inp.n_value,'string','100');
    set(data.inp.Te_value,'string','20');
    set(data.inp.Ti_value,'string','40');
elseif val == 4 % THEMIS
    data.probe_type='spherical';
    set(data.inp.probe_type,'Value',1);
    set(data.inp.probe_length_value,'style','text','string','');
    set(data.inp.probe_radius_value,'string','4');
    set(data.inp.sc_radius_value,'string','0.41');
    set(data.inp.sc_probe_refpot_as_fraction_of_scpot_value,'string','.2');
    set(data.inp.Rsun_value,'string','1');
    set(data.inp.probe_total_vs_sunlit_area_value,'string','4');
    data.probe_total_vs_sunlit_area=4;
    set(data.inp.n_value,'string','1');
    set(data.inp.Te_value,'string','100');
    set(data.inp.Ti_value,'string','500');
end
set(gcf,'userdata',data);
end