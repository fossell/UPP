      module vrbls2d
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
       implicit none
!
      real, allocatable ::                                    &
      U10   (:,:),AKMS  (:,:),AKHS  (:,:),THS   (:,:),QS(:,:) &
      ,UZ0(:,:),VZ0(:,:),THZ0(:,:),QZ0(:,:) &
      ,SNO   (:,:),TSHLTR   (:,:),QSHLTR(:,:) &
      ,V10(:,:),ACPREC(:,:),CUPREC(:,:),ANCPRC(:,:),CUPPT(:,:) &
      ,SMSTAV(:,:),SSROFF(:,:),BGROFF(:,:),VEGFRC(:,:) &
      ,ACSNOW(:,:),ACSNOM(:,:),CMC(:,:),SST(:,:) &
      ,RSWIN(:,:),RLWIN(:,:),RLWTOA(:,:) &
      ,TG(:,:),SFCSHX(:,:),PSLP(:,:) &
      ,SFCLHX(:,:),FIS(:,:),T500(:,:),Z1000(:,:),SLP(:,:) &
      ,CFRACL(:,:),CFRACM(:,:),CFRACH(:,:),ACFRST(:,:) &
      ,ACFRCV(:,:),NCFRST(:,:),NCFRCV(:,:),HBOT(:,:) &
      ,HTOP(:,:),ASWIN(:,:),ALWIN(:,:),ASWOUT(:,:) &
      ,ALWOUT(:,:),ASWTOA(:,:),ALWTOA(:,:),CZEN(:,:) &
      ,CZMEAN(:,:),SIGT4(:,:),RSWOUT(:,:),RADOT(:,:) &
      ,SMSTOT(:,:),PCTSNO(:,:),PSHLTR(:,:),TH10(:,:) &
      ,Q10(:,:),SR(:,:),PREC(:,:),SUBSHX(:,:) &
      ,SNOPCX(:,:),SFCUVX(:,:),SFCEVP(:,:),POTEVP(:,:) &
      ,Z0(:,:),USTAR(:,:),TWBS(:,:),QWBS(:,:) &
      ,SFCEXC(:,:),GRNFLX(:,:),SOILTB(:,:),F(:,:) &
      ,ALBEDO(:,:),CLDFRA(:,:),CPRATE(:,:),CNVCFR(:,:) &
      ,PBLH(:,:),HBOTD(:,:),HTOPD(:,:),HBOTS(:,:),HTOPS(:,:) &
      ,CLDEFI(:,:),ALBASE(:,:),SI(:,:),LSPA(:,:) &
      ,RSWINC(:,:),VIS(:,:),PD(:,:),MXSNAL(:,:),MIXHT(:,:) &
! NAMB additions
      ,SNOAVG(:,:),PSFCAVG(:,:),T10AVG(:,:),AKHSAVG(:,:),AKMSAVG(:,:) &
      ,T10M(:,:),U10MAX(:,:),V10MAX(:,:) &
! GSD addition
      ,WSPD10MAX(:,:),W_UP_MAX(:,:),W_DN_MAX(:,:),REFD_MAX(:,:) &
      ,UP_HELI_MAX(:,:),UP_HELI_MAX16(:,:),GRPL_MAX(:,:),QRMAX(:,:) &
      ,UP_HELI(:,:),UP_HELI16(:,:),LTG1_MAX(:,:),LTG2_MAX(:,:),LTG3_MAX(:,:) &
      ,NCI_LTG(:,:),NCA_LTG(:,:),NCI_WQ(:,:),NCA_WQ(:,:) &
      ,NCI_REFD(:,:),NCA_REFD(:,:) &
      ,RAINC_BUCKET(:,:),RAINNC_BUCKET(:,:),SNOW_BUCKET(:,:) &
      ,PCP_BUCKET(:,:) &
      ,SNOWNC(:,:),GRAUPELNC(:,:),TMAX(:,:),W_MEAN(:,:) &
      ,TSNOW(:,:),QVG(:,:),QV2m(:,:),VIL(:,:),RADARVIL(:,:) &
      ,ECHOTOP(:,:) &
! add new fields for GFS
      ,SFCUX(:,:),SFCVX(:,:),AVGALBEDO(:,:),AVGCPRATE(:,:) &
      ,AVGPREC(:,:),PTOP(:,:),PBOT(:,:),AVGCFRACH(:,:) &
      ,AVGCFRACM(:,:),AVGCFRACL(:,:),AVGTCDC(:,:) &
      ,AUVBIN(:,:),AUVBINC(:,:) &
      ,ptopl(:,:),pbotl(:,:),Ttopl(:,:) &
      ,ptopm(:,:),pbotm(:,:),Ttopm(:,:) &
      ,ptoph(:,:),pboth(:,:),Ttoph(:,:) &
      ,sfcugs(:,:),sfcvgs(:,:),PBLCFR(:,:) &
      ,cldwork(:,:),gtaux(:,:),gtauy(:,:),runoff(:,:) &
      ,maxtshltr(:,:),mintshltr(:,:),maxrhshltr(:,:)  &
      ,minrhshltr(:,:),dzice(:,:)                     &
      ,alwinc(:,:),alwoutc(:,:),alwtoac(:,:)          &
      ,aswinc(:,:),aswoutc(:,:),aswtoac(:,:),aswintoa(:,:) &
      ,smcwlt(:,:),suntime(:,:),fieldcapa(:,:)  &
      ,avisbeamswin(:,:),avisdiffswin(:,:),airbeamswin(:,:) &
      ,airdiffswin(:,:),snowfall(:,:)
      integer, allocatable :: IVGTYP(:,:),ISLTYP(:,:),ISLOPE(:,:) 
!
      end module vrbls2d