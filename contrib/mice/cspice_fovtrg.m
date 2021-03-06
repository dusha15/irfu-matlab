%-Abstract
%
%   CSPICE_FOVTRG determines if a specified ephemeris object is within
%   the field-of-view (FOV) of a specified instrument at a given time.
%
%-Disclaimer
%
%   THIS SOFTWARE AND ANY RELATED MATERIALS WERE CREATED BY THE
%   CALIFORNIA INSTITUTE OF TECHNOLOGY (CALTECH) UNDER A U.S.
%   GOVERNMENT CONTRACT WITH THE NATIONAL AERONAUTICS AND SPACE
%   ADMINISTRATION (NASA). THE SOFTWARE IS TECHNOLOGY AND SOFTWARE
%   PUBLICLY AVAILABLE UNDER U.S. EXPORT LAWS AND IS PROVIDED "AS-IS"
%   TO THE RECIPIENT WITHOUT WARRANTY OF ANY KIND, INCLUDING ANY
%   WARRANTIES OF PERFORMANCE OR MERCHANTABILITY OR FITNESS FOR A
%   PARTICULAR USE OR PURPOSE (AS SET FORTH IN UNITED STATES UCC
%   SECTIONS 2312-2313) OR FOR ANY PURPOSE WHATSOEVER, FOR THE
%   SOFTWARE AND RELATED MATERIALS, HOWEVER USED.
%
%   IN NO EVENT SHALL CALTECH, ITS JET PROPULSION LABORATORY, OR NASA
%   BE LIABLE FOR ANY DAMAGES AND/OR COSTS, INCLUDING, BUT NOT
%   LIMITED TO, INCIDENTAL OR CONSEQUENTIAL DAMAGES OF ANY KIND,
%   INCLUDING ECONOMIC DAMAGE OR INJURY TO PROPERTY AND LOST PROFITS,
%   REGARDLESS OF WHETHER CALTECH, JPL, OR NASA BE ADVISED, HAVE
%   REASON TO KNOW, OR, IN FACT, SHALL KNOW OF THE POSSIBILITY.
%
%   RECIPIENT BEARS ALL RISK RELATING TO QUALITY AND PERFORMANCE OF
%   THE SOFTWARE AND ANY RELATED MATERIALS, AND AGREES TO INDEMNIFY
%   CALTECH AND NASA FOR ALL THIRD-PARTY CLAIMS RESULTING FROM THE
%   ACTIONS OF RECIPIENT IN THE USE OF THE SOFTWARE.
%
%-I/O
%
%   Given:s
%
%      Parameters-
%
%      SPICE_GF_MAXVRT     is the maximum number of vertices that may be used
%                          to define the boundary of the specified instrument's
%                          field of view. See SpiceGF.h for more details.
%
%      MARGIN              is a small positive number used to constrain the
%                          orientation of the boundary vectors of polygonal
%                          FOVs. Such FOVs must satisfy the following
%                          constraints:
%
%                          1)  The boundary vectors must be contained within
%                              a right circular cone of angular radius less
%                              than than (pi/2) - MARGIN radians; in
%                              other words, there must be a vector A such that
%                              all boundary vectors have angular separation
%                              from A of less than (pi/2)-MARGIN radians.
%
%                          2)  There must be a pair of boundary vectors U, V
%                              such that all other boundary vectors lie in
%                              the same half space bounded by the plane
%                              containing U and V. Furthermore, all other
%                              boundary vectors must have orthogonal
%                              projections onto a specific plane normal to
%                              this plane (the normal plane contains the angle
%                              bisector defined by U and V) such that the
%                              projections have angular separation of at least
%                              2*MARGIN radians from the plane spanned
%                              by U and V.
%
%                          MARGIN is currently set to 1.D-6.
%
%      Arguments-
%
%      instrument    indicates the name of an instrument, such as a
%                    spacecraft-mounted framing camera. The field of view
%                    (FOV) of the instrument will be used to determine if
%                    the target is visible with respect to the instrument.
%
%                    [1,a] = size(instrument), char = class(instrument)
%
%                    The position of the instrument is considered to
%                    coincide with that of the ephemeris object 'observer' (see
%                    description below).
%
%                    The size of the instrument's FOV is constrained by the
%                    following: There must be a vector A such that all of
%                    the instrument's FOV boundary vectors have an angular
%                    separation from A of less than (pi/2)-MARGIN radians
%                    (see description above). For FOVs that are circular or
%                    elliptical, the vector A is the boresight. For FOVs
%                    that are rectangular or polygonal, the vector A is
%                    calculated.
%
%                    See the header of the CSPICE routine getfov_c for a
%                    description of the required parameters associated with
%                    an instrument.
%
%                    Both object names and NAIF IDs are accepted. For
%                    example, both 'CASSINI_ISS_NAC' and '-82360' are
%                    accepted. Case and leading or trailing blanks are not
%                    significant in the string.
%
%      target        is the name of the target body. This routine determines
%                    if the target body appears in the instrument's field of
%                    view.
%
%                    [1,b] = size(target), char = class(target)
%
%                    Both object names and NAIF IDs are accepted. For
%                    example, both 'Moon' and '301' are accepted. Case and
%                    leading or trailing blanks are not significant in the
%                    string.
%
%      target_shape  is a string indicating the geometric model used to
%                    represent the shape of the target body.
%
%                    [1,c] = size(target_shape), char = class(target_shape)
%
%                    The supported options are:
%
%                       'ELLIPSOID'     Use a triaxial ellipsoid model,
%                                       with radius values provided via the
%                                       kernel pool. A kernel variable
%                                       having a name of the form
%
%                                          'BODYnnn_RADII'
%
%                                       where nnn represents the NAIF
%                                       integer code associated with the
%                                       body, must be present in the kernel
%                                       pool. This variable must be
%                                       associated with three numeric
%                                       values giving the lengths of the
%                                       ellipsoid's X, Y, and Z semi-axes.
%
%                       'POINT'         Treat the body as a single point.
%
%                    Case and leading or trailing blanks are not
%                    significant in the string.
%
%      target_frame  is the name of the body-fixed, body-centered reference
%                    frame associated with the target body. Examples of
%                    such names are 'IAU_SATURN' (for Saturn) and 'ITRF93'
%                    (for the Earth).
%
%                    [1,d] = size(target_frame), char = class(target_frame)
%
%                    If the target body is modeled as a point, 'target_frame'
%                    is ignored and should be left blank. (Ex: ' ').
%
%                    Case and leading or trailing blanks bracketing a
%                    non-blank frame name are not significant in the string.
%
%      abcorr        indicates the aberration corrections to be applied
%                    when computing the target's position and orientation.
%
%                    [1,e] = size(abcorr), char = class(abcorr)
%
%                    For remote sensing applications, where the apparent
%                    position and orientation of the target seen by the
%                    observer are desired, normally either of the
%                    corrections:
%
%                        'LT+S'
%                        'CN+S'
%
%                    should be used. These and the other supported options
%                    are described below.
%
%                    Supported aberration correction options for
%                    observation (the case where radiation is received by
%                    observer at 'et') are:
%
%                        'NONE'         No correction.
%                        'LT'           Light time only
%                        'LT+S'         Light time and stellar aberration.
%                        'CN'           Converged Newtonian (CN) light time.
%                        'CN+S'         CN light time and stellar aberration.
%
%                    Supported aberration correction options for
%                    transmission (the case where radiation is emitted from
%                    observer at 'et') are:
%
%                        'XLT'          Light time only.
%                        'XLT+S'        Light time and stellar aberration.
%                        'XCN'          Converged Newtonian (CN) light time.
%                        'XCN+S'        CN light time and stellar aberration.
%
%                    Case, leading and trailing blanks are not significant
%                    in the string.
%
%      observer      is the name of the body from which the target is
%                    observed. The instrument 'instrument' is treated as if it
%                    were co-located with the observer.
%
%                    [1,f] = size(observer), char = class(observer)
%
%                    Both object names and NAIF IDs are accepted. For
%                    example, both 'CASSINI' and '-82' are accepted. Case and
%                    leading or trailing blanks are not significant in the
%                    string.
%
%      et            is the observation time in seconds past the J2000
%                    epoch.
%
%                    [1,n] = size(et), double = class(et)
%
%   the call:
%
%       visibl = cspice_fovtrg ( instrument,   target, target_shape, ...
%                                target_frame, abcorr, observer, et )
%
%   returns:
%
%       visibl       is true if 'target' is fully or partially in the
%                    field-of-view of 'instrument' at the time 'et'. Otherwise,
%                    'visibl' is false.
%
%                    [1,n] = size(visibl), logical = class(visibl)
%
%-Examples
%
%   Any numerical results shown for this example may differ between
%   platforms as the results depend on the SPICE kernels used as input
%   and the machine specific arithmetic implementation.
%
%
%   Example(1):
%
%      A spectacular picture was taken by Cassini's
%      narrow-angle camera on Oct. 6, 2010 that shows
%      six of Saturn's moons. Let's verify that the moons
%      in the picture are Epimetheus, Atlas, Daphnis, Pan,
%      Janus, and Enceladus.
%
%      To see this picture, visit:
%      http://photojournal.jpl.nasa.gov/catalog/PIA12741
%      or go to the PDS Image Node's Image Atlas at
%      http://pds-imaging.jpl.nasa.gov/search/search.html.
%      Select Cassini as the mission, ISS as the instrument,
%      and enter 1_N1665078907.122 as the Product ID in the
%      Product tab. Note: these directions may change as the
%      PDS Imaging Node changes.
%
%      Use the meta-kernel shown below to load the required SPICE
%      kernels. For project meta-kernels similar to the one shown
%      below, please see the PDS section of the NAIF FTP server.
%      For example, look at the following path for Cassini
%      meta-kernels: ftp://naif.jpl.nasa.gov//pub/naif/pds/data/
%      co-s_j_e_v-spice-6-v1.0/cosp_1000/extras/mk
%
%         KPL/MK
%
%         File name: fovtrg_ex.tm
%
%         This meta-kernel is intended to support operation of SPICE
%         example programs. The kernels shown here should not be
%         assumed to contain adequate or correct versions of data
%         required by SPICE-based user applications.
%
%         In order for an application to use this meta-kernel, the
%         kernels referenced here must be present in the user's
%         current working directory.
%
%         The names and contents of the kernels referenced
%         by this meta-kernel are as follows:
%
%            File name                     Contents
%            ---------                     --------
%            naif0010.tls                  Leapseconds
%            cpck*.tpc                     Satellite orientation and
%                                          radii
%            pck00010.tpc                  Planet orientation and
%                                          radii
%            cas_rocks_v18.tf              FK for small satellites
%                                          around Saturn
%            cas_v40.tf                    Cassini FK
%            cas_iss_v10.ti                Cassini ISS IK
%            cas00149.tsc                  Cassini SCLK
%            *.bsp                         Ephemeris for Cassini,
%                                          planets, and satellites
%            10279_10284ra.bc              Orientation for Cassini
%
%         \begindata
%
%            KERNELS_TO_LOAD = ( 'naif0010.tls'
%                                'cpck14Oct2010.tpc'
%                                'cpck_rock_21Jan2011_merged.tpc'
%                                'pck00010.tpc'
%                                'cas_rocks_v18.tf'
%                                'cas_v40.tf'
%                                'cas_iss_v10.ti'
%                                'cas00149.tsc'
%                                '110317AP_RE_90165_18018.bsp'
%                                '110120BP_IRRE_00256_25017.bsp'
%                                '101210R_SCPSE_10256_10302.bsp'
%                                '10279_10284ra.bc'              )
%
%         \begintext
%
%         End of meta-kernel
%
%       Example program starts here.
%
%         %
%         %   Load the meta kernel.
%         %
%         cspice_furnsh ( 'fovtrg_ex.tm' );
%
%         %
%         %   Retrieve Cassini's NAIF ID.
%         %
%         [cassini_id, found] = cspice_bodn2c ( 'cassini' );
%
%         if (~found)
%             fprintf ( 'Could not find ID code for Cassini.' );
%             return
%         end
%
%         %
%         %   Convert the image tag SCLK to ET.
%         %
%         et = cspice_scs2e ( cassini_id, '1665078907.122' );
%
%         %
%         %   Convert the ET to a string format for the output.
%         %
%         time_format = 'YYYY-MON-DD HR:MN:SC.###::TDB (TDB)';
%         time = cspice_timout ( et, time_format );
%
%         %
%         %   Search through all of Saturn's moons to see if each
%         %   satellite was in the ISS NAC's field-of-view at
%         %   the image time. We're going to take advantage of the
%         %   fact that all Saturn's moons have a NAIF ID of 6xx.
%         %
%         fprintf ( 'At time %s the following were\n', time     );
%         fprintf ( 'in the field of view of CASSINI_ISS_NAC\n' );
%         for body_id = 600:699
%             %
%             %   Check to see if the 'body_id' has a translation.
%             %
%             [body, found] = cspice_bodc2n ( body_id );
%
%             if (found)
%                 %
%                 %   Check to see if a body-fixed frame for this ID exists.
%                 %   If the frame is not in the kernel pool, we cannot
%                 %   perform the visibility test. The main cause of a
%                 %   failure is a missing kernel.
%                 %
%                 [frame_code, frame_name, found] = cspice_cidfrm ( body_id );
%
%                 if (found)
%                     %
%                     %   Is this body in the field-of-view of Cassini's
%                     %   ISS narrow-angle camera?
%                     %
%                     visibl = cspice_fovtrg ( 'cassini_iss_nac', body, ...
%                                     'ellipsoid', frame_name, 'cn+s', ...
%                                     'cassini', et );
%                     if ( visibl )
%                         fprintf ( '  %s\n', body);
%                     end
%                 end
%             end
%         end
%         %
%         %   Unload the kernels.
%         %
%         cspice_kclear
%
%   MATLAB outputs:
%
%         At time 2010-OCT-06 17:09:45.346 (TDB) the following were
%         in the field of view of CASSINI_ISS_NAC
%           ENCELADUS
%           JANUS
%           EPIMETHEUS
%           ATLAS
%           PAN
%           DAPHNIS
%           ANTHE
%
%         Note: there were actually 7 of Saturn's satellites in the
%         field-of-view of Cassini's narrow-angle camera. However, Anthe
%         is very small and was probably obscured by other objects or
%         shadow.
%
%-Particulars
%
%   To treat the target as a ray rather than as an ephemeris object,
%   use the higher-level Mice routine cspice_fovray. cspice_fovray may be used
%   to determine if distant target objects such as stars are visible
%   in an instrument's FOV at a given time, as long as the direction
%   from the observer to the target can be modeled as a ray.
%
%-Required Reading
%
%   For important details concerning this module's function, please refer to
%   the CSPICE routine fovtrg_c.
%
%   MICE.REQ
%   DAF.REQ
%
%-Version
%
%   -Mice Version 1.0.0, 16-FEB-2012, SCK (JPL)
%
%-Index_Entries
%
%   Target in instrument FOV at specified time
%   Target in instrument field_of_view at specified time
%
%
%-&

function visibl = cspice_fovtrg ( instrument, target, target_shape, ...
                                  target_frame, abcorr, observer, et )

    switch nargin
        case 7

            instrument   = zzmice_str(instrument);
            target       = zzmice_str(target);
            target_shape = zzmice_str(target_shape);
            target_frame = zzmice_str(target_frame);
            abcorr       = zzmice_str(abcorr);
            observer     = zzmice_str(observer);
            et           = zzmice_dp (et);

        otherwise

            error ( ['Usage: [_visibl_] = ' ...
                  'cspice_fovtrg( `instrument`, `target`, ' ...
                  '`target_shape`, `target_frame`, `abcorr`), ' ...
                  '`observer`, _et_]' ] )

   end


   %
   % Call the MEX library. An "_s" suffix indicates a structure type
   % return argument (not present in this case).
   %
   try
      [visibl] = mice('fovtrg_c', instrument, target, target_shape, ...
                                  target_frame, abcorr, observer, et );
      visibl = zzmice_logical ( visibl );
   catch
      rethrow(lasterror)
   end


























