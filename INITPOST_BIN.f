      SUBROUTINE INITPOST_BIN
!$$$  SUBPROGRAM DOCUMENTATION BLOCK
!                .      .    .     
! SUBPROGRAM:    INITPOST    INITIALIZE POST FOR RUN
!   PRGRMMR: RUSS TREADON    ORG: W/NP2      DATE: 93-11-10
!     
! ABSTRACT:  THIS ROUTINE INITIALIZES CONSTANTS AND
!   VARIABLES AT THE START OF AN ETA MODEL OR POST 
!   PROCESSOR RUN.
!
!   THIS ROUTINE ASSUMES THAT INTEGERS AND REALS ARE THE SAME SIZE
!   .     
!     
! PROGRAM HISTORY LOG:
!   93-11-10  RUSS TREADON - ADDED DOCBLOC
!   98-05-29  BLACK - CONVERSION OF POST CODE FROM 1-D TO 2-D
!   99-01 20  TUCCILLO - MPI VERSION
!   01-10-25  H CHUANG - MODIFIED TO PROCESS HYBRID MODEL OUTPUT
!   02-06-19  MIKE BALDWIN - WRF VERSION
!   02-08-15  H CHUANG - UNIT CORRECTION AND GENERALIZE PROJECTION OPTIONS
!   02-10-31  H CHUANG - MODIFY TO READ WRF BINARY OUTPUT
!     
! USAGE:    CALL INIT
!   INPUT ARGUMENT LIST:
!     NONE     
!
!   OUTPUT ARGUMENT LIST: 
!     NONE
!     
!   OUTPUT FILES:
!     NONE
!     
!   SUBPROGRAMS CALLED:
!     UTILITIES:
!       NONE
!     LIBRARY:
!       COMMON   - CTLBLK
!                  LOOKUP
!                  SOILDEPTH
!
!    
!   ATTRIBUTES:
!     LANGUAGE: FORTRAN
!     MACHINE : CRAY C-90
!$$$  
      use vrbls3d
      use vrbls2d
      use soil
      use masks
      use params_mod
      use lookup_mod
      use ctlblk_mod
      use gridspec_mod
      use wrf_io_flags_mod
!
      implicit none
!
!     INCLUDE/SET PARAMETERS.
      INCLUDE "mpif.h"
!
! This version of INITPOST shows how to initialize, open, read from, and
! close a NetCDF dataset. In order to change it to read an internal (binary)
! dataset, do a global replacement of _ncd_ with _int_. 

      character(len=31) :: VarName
      integer :: Status
      character startdate*19,SysDepInfo*80
! 
!     NOTE: SOME INTEGER VARIABLES ARE READ INTO DUMMY ( A REAL ). THIS IS OK
!     AS LONG AS REALS AND INTEGERS ARE THE SAME SIZE.
!
!     ALSO, EXTRACT IS CALLED WITH DUMMY ( A REAL ) EVEN WHEN THE NUMBERS ARE
!     INTEGERS - THIS IS OK AS LONG AS INTEGERS AND REALS ARE THE SAME SIZE.
      LOGICAL RUNB,SINGLRST,SUBPOST,NEST,HYDRO
      LOGICAL IOOMG,IOALL
      CHARACTER*32 LABEL
      CHARACTER*40 CONTRL,FILALL,FILMST,FILTMP,FILTKE,FILUNV,          &
     &  FILCLD,FILRAD,FILSFC
      CHARACTER*4 RESTHR
      CHARACTER FNAME*80,ENVAR*50,BLANK*4
      INTEGER IDATB(3),IDATE(8),JDATE(8)
!
!     DECLARE VARIABLES.
!     
      REAL SLDPTH2(NSOIL)
      REAL RINC(5)
      REAL DUM1D (LM+1)
      REAL DUMMY ( IM, JM )
      REAL DUMMY2 ( IM, JM ),MSFT(IM,JM)
      INTEGER IDUMMY ( IM, JM )
      REAL DUM3D ( IM+1, JM+1, LM+1 )
      REAL DUM3D2 ( IM+1, JM+1, LM+1 )
        real, allocatable::  pvapor(:,:)
        real, allocatable::  pvapor_orig(:,:)      
!jw
      integer js,je,jev,iyear,imn,iday,itmp,ioutcount,istatus,          &
        ii,jj,ll,L,N,I,J,NRDLW,NRDSW,IRTN,IGDOUT,NSRFC
      integer LAT_LL_T,LAT_UL_T,LAT_UR_T,LAT_LR_T
      integer LON_LL_T,LON_UL_T,LON_UR_T,LON_LR_T
      real TLMH,TSPH,dz,pvapornew,qmean,rho,tmp,dumcst
!
      DATA BLANK/'    '/

!
!***********************************************************************
!     START INIT HERE.
!
      WRITE(6,*)'INITPOST:  ENTER INITPOST'
!     
!     
!     STEP 1.  READ MODEL OUTPUT FILE
!
!
!***
!
! LMH always = LM for sigma-type vert coord
! LMV always = LM for sigma-type vert coord

       do j = jsta_2l, jend_2u
        do i = 1, im
            LMV ( i, j ) = lm
            LMH ( i, j ) = lm
        end do
       end do


! HTM VTM all 1 for sigma-type vert coord

      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
            HTM ( i, j, l ) = 1.0
            VTM ( i, j, l ) = 1.0
        end do
       end do
      end do
!
!      DateStr = '2002-03-05_18:00:00'
!  how do I get the filename?
         call ext_int_ioinit(SysDepInfo,Status)
          print*,'called ioinit', Status
         call ext_int_open_for_read( trim(fileName), 0, 0, " ",        &
     &  DataHandle, Status)
          print*,'called open for read', Status
       if ( Status /= 0 ) then
         print*,'error opening ',fileName, ' Status = ', Status ; stop
       endif
! get date/time info
!  this routine will get the next time from the file, not using it
      print *,'DateStr before calling ext_int_get_next_time=',DateStr
!      call ext_int_get_next_time(DataHandle, DateStr, Status)
      print *,'DateStri,Status,DataHandle = ',DateStr,Status,DataHandle

!  The end j row is going to be jend_2u for all variables except for V.
      JS=JSTA_2L
      JE=JEND_2U
      IF (JEND_2U.EQ.JM) THEN
       JEV=JEND_2U+1
      ELSE
       JEV=JEND_2U
      ENDIF
!
! Getting start time
      call ext_int_get_dom_ti_char(DataHandle,'START_DATE',startdate,  &
        status )
      print*,'startdate= ',startdate
      jdate=0
      idate=0
      read(startdate,15)iyear,imn,iday,ihrst,imin      
 15   format(i4,1x,i2,1x,i2,1x,i2,1x,i2)
      print*,'start yr mo day hr min=',iyear,imn,iday,ihrst,imin
      print*,'processing yr mo day hr min=',idat(3),idat(1),idat(2),     &
        idat(4),idat(5)
      idate(1)=iyear
      idate(2)=imn
      idate(3)=iday
      idate(5)=ihrst
      idate(6)=imin
      SDAT(1)=imn
      SDAT(2)=iday
      SDAT(3)=iyear
      jdate(1)=idat(3)
      jdate(2)=idat(1)
      jdate(3)=idat(2)
      jdate(5)=idat(4)
      jdate(6)=idat(5)
      CALL W3DIFDAT(JDATE,IDATE,0,RINC)
      ifhr=nint(rinc(2)+rinc(1)*24.)
      ifmin=nint(rinc(3))
      print*,' in INITPOST ifhr ifmin fileName=',ifhr,ifmin,fileName
!  OK, since all of the variables are dimensioned/allocated to be
!  the same size, this means we have to be careful int getVariable
!  to not try to get too much data.  For example, 
!  DUM3D is dimensioned IM+1,JM+1,LM+1 but there might actually
!  only be im,jm,lm points of data available for a particular variable.  
! get metadata
        call ext_int_get_dom_ti_integer(DataHandle,'MP_PHYSICS'         &
          ,itmp,1,ioutcount,istatus)
        imp_physics=itmp
        print*,'MP_PHYSICS= ',imp_physics
	
	call ext_int_get_dom_ti_integer(DataHandle,'CU_PHYSICS'          &
          ,itmp,1,ioutcount,istatus)
        icu_physics=itmp
        print*,'CU_PHYSICS= ',icu_physics
	
        call ext_int_get_dom_ti_real(DataHandle,'DX',tmp                 &
          ,1,ioutcount,istatus)
        dxval=nint(tmp)
        write(6,*) 'dxval= ', dxval
        call ext_int_get_dom_ti_real(DataHandle,'DY',tmp                 &
          ,1,ioutcount,istatus)
        dyval=nint(tmp)
        write(6,*) 'dyval= ', dyval
        call ext_int_get_dom_ti_real(DataHandle,'CEN_LAT',tmp            &
          ,1,ioutcount,istatus)
        cenlat=nint(1000.*tmp)
        write(6,*) 'cenlat= ', cenlat
        call ext_int_get_dom_ti_real(DataHandle,'CEN_LON',tmp            &
          ,1,ioutcount,istatus)
        cenlon=nint(1000.*tmp)
        write(6,*) 'cenlon= ', cenlon
        call ext_int_get_dom_ti_real(DataHandle,'TRUELAT1',tmp           &
          ,1,ioutcount,istatus)
        truelat1=nint(1000.*tmp)
        write(6,*) 'truelat1= ', truelat1
        call ext_int_get_dom_ti_real(DataHandle,'TRUELAT2',tmp           &
          ,1,ioutcount,istatus)
        truelat2=nint(1000.*tmp)
        write(6,*) 'truelat2= ', truelat2
	call ext_int_get_dom_ti_real(DataHandle,'STAND_LON',tmp          &
          ,1,ioutcount,istatus)
        STANDLON=nint(1000.*tmp)
        write(6,*) 'STANDLON= ', STANDLON
        call ext_int_get_dom_ti_integer(DataHandle,'MAP_PROJ',itmp       &
          ,1,ioutcount,istatus)
        maptype=itmp
        write(6,*) 'maptype is ', maptype
!need to get DT
        call ext_int_get_dom_ti_real(DataHandle,'DT',tmp                 &
          ,1,ioutcount,istatus)
        DT=tmp
        print*,'DT= ',DT

! get 3-D variables
      VarName='LU_INDEX'
	write(6,*) 'call getIVariable for : ', VarName
      call getIVariable(fileName,DateStr,DataHandle,VarName,IDUMMY,      &
         IM,1,JM,1,IM,JS,JE,1)

      print*,'im,jm,lm= ',im,jm,lm
!
      VarName='U'
!      call getVariable(fileName,DateStr,DataHandle,'U',DUM3D,
!        IM+1,1,JM+1,LM+1,IM+1,JS,JE,LM)
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM+1,JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im+1
            u ( i, j, l ) = dum3d ( i, j, l )
        end do
       end do
!  fill up UH which is U at P-points including 2 row halo
       do j = jsta_2l, jend_2u
        do i = 1, im
            UH (I,J,L) = (dum3d(I,J,L)+dum3d(I+1,J,L))*0.5
        end do
       end do
      end do
      ii=im/2
      jj=(jsta+jend)/2
      ll=lm
!      print*,'UH at ',ii,jj,ll,' = ',UH (ii,jj,ll)
!      call getVariable(fileName,DateStr,DataHandle,'V',DUM3D,
!        IM+1,1,JM+1,LM+1,IM,JS,JEV,LM)
      VarName='V'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM,JS,JEV,LM)
      do l = 1, lm
       do j = jsta_2l, jev
        do i = 1, im
            v ( i, j, l ) = dum3d ( i, j, l )
        end do
       end do
!  fill up VH which is V at P-points including 2 row halo
       do j = jsta_2l, jend_2u
        do i = 1, im
          VH(I,J,L) = (dum3d(I,J,L)+dum3d(I,J+1,L))*0.5
        end do
       end do
      end do
      print*,'finish reading V'
!      print*,'VH at ',ii,jj,ll,' = ',VH (ii,jj,ll)
!
!      call getVariable(fileName,DateStr,DataHandle,'W',DUM3D,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM+1)
      VarName='W'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       & 
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM+1)
!      do l = 1, lm+1
!       do j = jsta_2l, jend_2u
!        do i = 1, im
!            w ( i, j, l ) = dum3d ( i, j, l )
!        end do
!       end do
!      end do
!  fill up WH which is W at P-points including 2 row halo
      DO L=1,LM
        DO I=1,IM
         DO J=JSTA_2L,JEND_2U
          WH(I,J,L) = (DUM3D(I,J,L)+DUM3D(I,J,L+1))*0.5
         ENDDO
        ENDDO
      ENDDO
!      print*,'WH at ',ii,jj,ll,' = ',WH (ii,jj,ll)
      print*,'finish reading W'
!
!
!      VarName='WW'
!      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM+1)
!
! reading geopotential
!      call getVariable(fileName,DateStr,DataHandle,'PHB',DUM3D,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM+1)
!      call getVariable(fileName,DateStr,DataHandle,'PH',DUM3D2,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM+1)
      VarName='PH'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D2,      &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM+1)
      VarName='PHB'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM+1)
      print*,'finish reading geopotential'
! ph/phb are geopotential z=(ph+phb)/9.801
      DO L=1,LM+1
        DO I=1,IM
         DO J=JS,JE
          ZINT(I,J,L)=(DUM3D(I,J,L)+DUM3D2(I,J,L))/G
         ENDDO
        ENDDO
      ENDDO
      DO L=1,LM
       DO I=1,IM
        DO J=JS,JE
         ZMID(I,J,L)=(ZINT(I,J,L+1)+ZINT(I,J,L))*0.5  ! ave of z
        ENDDO
       ENDDO
      ENDDO
!      print*,'ZMID at ',ii,jj,ll,' = ',ZMID(ii,jj,ll)      
!      print*,'ZINT at ',ii,jj,ll+1,' = ',ZINT(ii,jj,ll+1)
!
! reading potential temperature
!      call getVariableB(fileName,DateStr,DataHandle,'T',DUM3D,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
      VarName='T'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
            t ( i, j, l ) = dum3d ( i, j, l ) + 300.
!MEB  this is theta the 300 is my guess at what T0 is
        end do
       end do
      end do
      do l=1,lm
!       print*,'theta at ',ii,jj,l,' = ',TH(ii,jj,l)
      end do
      print*,'finish reading T'
!
! reading sfc pressure
      VarName='MU'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
      VarName='MUB'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY2,      &  
        IM,1,JM,1,IM,JS,JE,1)
      DO I=1,IM
            DO J=JS,JE
!                 PINT (I,J,LM+1) = DUMMY(I,J)+DUMMY2(I,J)+PT
                 PINT (I,J,LM+1) = DUMMY(I,J)+DUMMY2(I,J) !PSFC-PT
!                 PINT (I,J,1) = PT
!                 ALPINT(I,J,LM+1)=ALOG(PINT(I,J,LM+1))
!                 ALPINT(I,J,1)=ALOG(PINT(I,J,1))
            ENDDO
         ENDDO
!


      VarName='MU0'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)

      VarName='NEST_POS'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)

      VarName='P'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D2,     &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)

      VarName='PB'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,      &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
!
!      call getVariable(fileName,DateStr,DataHandle,'PB',DUM3D,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
!      call getVariable(fileName,DateStr,DataHandle,'P',DUM3D2,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
            PMID(I,J,L)=DUM3D(I,J,L)+DUM3D2(I,J,L)
! now that I have P, convert theta to t
            t( i, j, l ) = T(I,J,L)*(PMID(I,J,L)*1.E-5)**CAPA

        end do
       end do
      end do
      DO L=2,LM
         DO I=1,IM
            DO J=JSTA_2L,JEND_2U
!              PINT(I,J,L)=EXP((ALOG(PMID(I,J,L-1))+
!     &                 ALOG(PMID(I,J,L)))*0.5)  ! ave of ln p
              PINT(I,J,L)=(PMID(I,J,L-1)+PMID(I,J,L))*0.5
              ALPINT(I,J,L)=ALOG(PINT(I,J,L))
            ENDDO
         ENDDO
      END DO
!      print*,'PINT at ',ii,jj,ll,' = ',pint(ii,jj,ll)
!      print*,'T at ',ii,jj,ll,' = ',t(ii,jj,ll)
      
      VarName='SR'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            SR ( i, j ) = dummy ( i, j )
        end do
       end do      

      VarName='FNM'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,LM,1,1,1,LM)

      VarName='FNP'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,LM,1,1,1,LM)

      VarName='RDNW'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,LM,1,1,1,LM)

      VarName='RDN'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,LM,1,1,1,LM)
     
      VarName='DNW'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,LM,1,1,1,LM)

      VarName='DN'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,LM,1,1,1,LM)

      VarName='ZNU'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,LM,1,1,1,LM)

      VarName='ZNW'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,LM+1,1,1,1,LM+1)
     
      VarName='CFN'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,1,1,1,1,1)
                                                                                  
      VarName='CFN1'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,1,1,1,1,1)
      
      VarName='EPSTS'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,1,1,1,1,1)

! reading 2 m mixing ratio 
      VarName='Q2'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
!HC            QSHLTR ( i, j ) = dummy ( i, j )
!HC CONVERT FROM MIXING RATIO TO SPECIFIC HUMIDITY
            QSHLTR ( i, j ) = dummy ( i, j )/(1.0+dummy ( i, j ))
        end do
       end do
!       print*,'QSHLTR at ',ii,jj,' = ',QSHLTR(ii,jj)
!
      VarName='T2'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
! reading 2m theta
      VarName='TH2'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            TSHLTR ( i, j ) = dummy ( i, j )
        end do
       end do
!       print*,'TSHLTR at ',ii,jj,' = ',TSHLTR(ii,jj)
!
      VarName='PSFC'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY2,      &
        IM,1,JM,1,IM,JS,JE,1)


! reading 10 m wind
      VarName='U10'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY2,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            U10 ( i, j ) = dummy2( i, j )
        end do
       end do
!       print*,'U10 at ',ii,jj,' = ',U10(ii,jj)

      VarName='V10'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY2,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jev
        do i = 1, im
            V10 ( i, j ) = dummy2( i, j )
        end do
       end do
!       print*,'V10 at ',ii,jj,' = ',V10(ii,jj)

       do j = jsta_2l, jend_2u
        do i = 1, im
            TH10 ( i, j ) = SPVAL
	    Q10 ( i, j ) = SPVAL
        end do
       end do
   
      VarName='RDX'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,1,1,1,1,1)
                                                                                  
      VarName='RDY'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,1,1,1,1,1)
      
      VarName='RESM'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,1,1,1,1,1)   

      VarName='ZETATOP'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,1,1,1,1,1)
                                                                                  
      VarName='CF1'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,1,1,1,1,1)
      
      VarName='CF2'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,1,1,1,1,1)
       
      VarName='CF3'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM1D,      &
        1,1,1,1,1,1,1,1)

      VarName='ITIMESTEP'
      call getIVariable(fileName,DateStr,DataHandle,VarName,IDUMMY,     &
        1,1,1,1,1,1,1,1)

!
!      call getVariable(fileName,DateStr,DataHandle,'PB',DUM3D,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
!      call getVariable(fileName,DateStr,DataHandle,'P',DUM3D2,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
!t      do l = 1, lm
!t       do j = jsta_2l, jend_2u
!t        do i = 1, im
!t            PMID(I,J,L)=DUM3D(I,J,L)+DUM3D2(I,J,L)
!t! now that I have P, convert theta to t
!t            t ( i, j, l ) = T(I,J,L)*(PMID(I,J,L)*1.E-5)**CAPA
!t! now that I have T,q,P  compute omega from wh
!t            omga(I,J,L) = -WH(I,J,L)*pmid(i,j,l)*9.801/
!t     &                        (287.04*t(i,j,l)*(1.+0.608*q(i,j,l)))
!t        end do
!t       end do
!t      end do
!t      DO L=2,LM
!t         DO I=1,IM
!t            DO J=JSTA_2L,JEND_2U
!t              PINT(I,J,L)=EXP((ALOG(PMID(I,J,L-1))+
!t     &                 ALOG(PMID(I,J,L)))*0.5)  ! ave of ln p
!t              ALPINT(I,J,L)=ALOG(PINT(I,J,L))
!t            ENDDO
!t         ENDDO
!t      END DO 
!
! reading water vapor mixing ratio
      VarName='QVAPOR'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
!      call getVariable(fileName,DateStr,DataHandle,'QVAPOR',DUM3D,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
!HC            q ( i, j, l ) = dum3d ( i, j, l )
!HC CONVERT MIXING RATIO TO SPECIFIC HUMIDITY
            q ( i, j, l ) = dum3d ( i, j, l )/(1.0+dum3d ( i, j, l ))
! now that I have T,q,P  compute omega from wh
            omga(I,J,L) = -WH(I,J,L)*pmid(i,j,l)*G/                       &
                              (RD*t(i,j,l)*(1.+D608*q(i,j,l)))
        end do
       end do
      end do
!      print*,'Q at ',ii,jj,ll,' = ',Q(ii,jj,ll)

!!!!!!!!!!!!!
! Pyle's and Chuang's fixes for ARW SLP

        allocate(pvapor(IM,jsta_2l:jend_2u))
        allocate(pvapor_orig(IM,jsta_2l:jend_2u))
        DO J=jsta,jend
        DO I=1,IM


        pvapor(I,J)=0.
       do L=1,LM
       dz=ZINT(I,J,L)-ZINT(I,J,L+1)
       rho=PMID(I,J,L)/(RD*T(I,J,L))


        if (L .le. LM-1) then
        QMEAN=0.5*(Q(I,J,L)+Q(I,J,L+1))
        else
        QMEAN=Q(I,J,L)
        endif


       pvapor(I,J)=pvapor(I,J)+G*rho*dz*QMEAN
       enddo


! test elim
!       pvapor(I,J)=0.


        pvapor_orig(I,J)=pvapor(I,J)


      ENDDO
      ENDDO

      do L=1,405
        call exch(pvapor(1,jsta_2l))
        do J=JSTA_M,JEND_M
        do I=2,IM-1

        pvapornew=AD05*(4.*(pvapor(I-1,J)+pvapor(I+1,J)                 & 
                        +pvapor(I,J-1)+pvapor(I,J+1))                   &
                        +pvapor(I-1,J-1)+pvapor(I+1,J-1)                &
                        +pvapor(I-1,J+1)+pvapor(I+1,J+1))               &
                        -CFT0*pvapor(I,J)

        pvapor(I,J)=pvapornew

        enddo
        enddo
        enddo   ! iteration loop

! southern boundary
        if (JS .eq. 1) then
        J=1
        do I=2,IM-1
        pvapor(I,J)=pvapor_orig(I,J)+(pvapor(I,J+1)-pvapor_orig(I,J+1))
        enddo
        endif

! northern boundary

        if (JE .eq. JM) then
        J=JM
        do I=2,IM-1
        pvapor(I,J)=pvapor_orig(I,J)+(pvapor(I,J-1)-pvapor_orig(I,J-1))
        enddo
        endif

! western boundary
        I=1
        do J=JS,JE
        pvapor(I,J)=pvapor_orig(I,J)+(pvapor(I+1,J)-pvapor_orig(I+1,J))
        enddo

! eastern boundary
        I=IM
        do J=JS,JE
        pvapor(I,J)=pvapor_orig(I,J)+(pvapor(I-1,J)-pvapor_orig(I-1,J))
        enddo

      DO J=Jsta,jend
      DO I=1,IM
              PINT(I,J,LM+1)=PINT(I,J,LM+1)+PVAPOR(I,J)
      ENDDO
      ENDDO

        write(6,*) 'surface pvapor field (post-smooth)'

        deallocate(pvapor)
        deallocate(pvapor_orig)


!!!!!!!!!!!!!

! reading cloud water mixing ratio
! Brad comment out the output of individual species for Ferrier's scheme within 
! ARW in Registry file

      qqw=0.
      qqr=0.
      qqs=0.
      qqi=0.
      qqg=0. 
      cwm=0.
 
      if(imp_physics.ne.5 .and. imp_physics.ne.0)then 
      VarName='QCLOUD'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
!      call getVariable(fileName,DateStr,DataHandle,'QCLOUD',DUM3D,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
! partition cloud water and ice for WSM3 
	    if(imp_physics.eq.3)then 
             if(t(i,j,l) .ge. TFRZ)then  
              qqw ( i, j, l ) = dum3d ( i, j, l )
	     else
	      qqi  ( i, j, l ) = dum3d ( i, j, l )
	     end if
            else ! bug fix provided by J CASE
             qqw ( i, j, l ) = dum3d ( i, j, l ) 
	    end if  	     
        end do
       end do
      end do
!      print*,'qqw at ',ii,jj,ll,' = ',qqw(ii,jj,ll)
      end if


      if(imp_physics.ne.5 .and. imp_physics.ne.0)then
      VarName='QRAIN'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
!      call getVariable(fileName,DateStr,DataHandle,'QCLOUD',DUM3D,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
! partition rain and snow for WSM3 	
          if(imp_physics .eq. 3)then
	    if(t(i,j,l) .ge. TFRZ)then  
             qqr ( i, j, l ) = dum3d ( i, j, l )
	    else
	     qqs ( i, j, l ) = dum3d ( i, j, l )
	    end if
           else
            qqr ( i, j, l ) = dum3d ( i, j, l )  
	   end if 
        end do
       end do
      end do
!      print*,'qqr at ',ii,jj,ll,' = ',qqr(ii,jj,ll)
      end if

      if(imp_physics.ne.1 .and. imp_physics.ne.3                        &
        .and. imp_physics.ne.5 .and. imp_physics.ne.0)then
      VarName='QICE'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
!      call getVariable(fileName,DateStr,DataHandle,'QCLOUD',DUM3D,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
            qqi ( i, j, l ) = dum3d ( i, j, l )
        end do
       end do
      end do
!      print*,'qqi at ',ii,jj,ll,' = ',qqi(ii,jj,ll)
      end if
      
      if(imp_physics.ne.1 .and. imp_physics.ne.3                         &
       .and. imp_physics.ne.5 .and. imp_physics.ne.0)then
      VarName='QSNOW'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
!      call getVariable(fileName,DateStr,DataHandle,'QCLOUD',DUM3D,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
            qqs ( i, j, l ) = dum3d ( i, j, l )
        end do
       end do
      end do
!      print*,'qqs at ',ii,jj,ll,' = ',qqs(ii,jj,ll)
      end if

      if(imp_physics.eq.2 .or. imp_physics.eq.6                         &
            .or. imp_physics.eq.8)then
      VarName='QGRAUP'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
!      call getVariable(fileName,DateStr,DataHandle,'QCLOUD',DUM3D,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
!HC            cwm ( i, j, l ) = dum3d ( i, j, l )
!HC CONVERT MIXING RATIO TO SPECIFIC HUMIDITY
            qqg ( i, j, l ) = dum3d ( i, j, l )
        end do
       end do
      end do
!      print*,'qqg at ',ii,jj,ll,' = ',qqg(ii,jj,ll)
      end if
      
      if(imp_physics.ne.5)then
!HC SUM UP ALL CONDENSATE FOR CWM
       do l = 1, lm
        do j = jsta_2l, jend_2u
         do i = 1, im
          IF(QQR(I,J,L).LT.SPVAL)THEN
           CWM(I,J,L)=QQR(I,J,L)
          END IF
          IF(QQI(I,J,L).LT.SPVAL)THEN
           CWM(I,J,L)=CWM(I,J,L)+QQI(I,J,L)
          END IF
          IF(QQW(I,J,L).LT.SPVAL)THEN
           CWM(I,J,L)=CWM(I,J,L)+QQW(I,J,L)
          END IF
          IF(QQS(I,J,L).LT.SPVAL)THEN
           CWM(I,J,L)=CWM(I,J,L)+QQS(I,J,L)
          END IF
          IF(QQG(I,J,L).LT.SPVAL)THEN
           CWM(I,J,L)=CWM(I,J,L)+QQG(I,J,L)
          END IF 
         end do
        end do
       end do
      else
       VarName='CWM'
       call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
         IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
       do l = 1, lm
        do j = jsta_2l, jend_2u
         do i = 1, im
            CWM ( i, j, l ) = dum3d ( i, j, l )
         end do
        end do
       end do 
      end if 

      VarName='LANDMASK'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY2,      &
        IM,1,JM,1,IM,JS,JE,1)

   
!
! reading soil temperature
      VarName='TSLB'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM,JS,JE,NSOIL)
      do l = 1, nsoil
       do j = jsta_2l, jend_2u
        do i = 1, im
!            stc ( i, j, l ) = dum3d ( i, j, l )
! flip soil layer again because wrf soil variable vertical indexing
! is the same with eta and vertical indexing was flipped for both
! atmospheric and soil layers within getVariable
            stc ( i, j, l ) = dum3d ( i, j, nsoil-l+1)
        end do
       end do
      end do
!      print*,'STC at ',ii,jj,N,' = ',stc(ii,jj,1),stc(ii,jj,2)
!     &,stc(ii,jj,3),stc(ii,jj,4)
!
! bitmask out high, middle, and low cloud cover
       do j = jsta_2l, jend_2u
        do i = 1, im
            CFRACH ( i, j ) = SPVAL/100.
	    CFRACL ( i, j ) = SPVAL/100.
	    CFRACM ( i, j ) = SPVAL/100.
        end do
       end do

      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
            CFR( i, j, l ) = SPVAL
        end do
       end do
      end do
                            
! either assign SLDPTH to be the same as eta (which is original
! setup in WRF LSM) or extract thickness of soil layers from wrf
! output

! assign SLDPTH to be the same as eta


!!!!! PROBLEM STARTS HERE
	write(0,*) 'to here'
      
      VarName='ZS'
      call getVariableB(fileName,DateStr,DataHandle,VarName,SLDPTH2,    &  
       1,1,1,NSOIL,1,1,1,NSOIL)

	write(0,*) 'return getVariable for ZS'

         SLDPTH(1)=0.10
         SLDPTH(2)=0.3
         SLDPTH(3)=0.6
         SLDPTH(4)=1.0

! or get SLDPTH from wrf output
      call getVariableB(fileName,DateStr,DataHandle,'DZS',SLDPTH2,      &
       1,1,1,NSOIL,1,1,1,NSOIL)
	write(0,*) 'return getVariable for DZS'
! if SLDPTH in wrf output is non-zero, then use it
      DUMCST=0.0
      DO N=1,NSOIL
       DUMCST=DUMCST+SLDPTH2(N)
      END DO 
      IF(ABS(DUMCST-0.).GT.1.0E-2)THEN
       DO N=1,NSOIL
        SLDPTH(N)=SLDPTH2(N)
       END DO
      END IF
      print*,'SLDPTH= ',(SLDPTH(N),N=1,NSOIL)
!
!
! reading soil moisture
      VarName='SMOIS'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM,JS,JE,NSOIL)
      do l = 1, nsoil
       do j = jsta_2l, jend_2u
        do i = 1, im
!            smc ( i, j, l ) = dum3d ( i, j, l )
            smc ( i, j, l ) = dum3d ( i, j, nsoil-l+1)
        end do
       end do
      end do
!      print*,'SMC at ',ii,jj,N,' = ',smc(ii,jj,1),smc(ii,jj,2)
!     &,smc(ii,jj,3),smc(ii,jj,4),smc(ii,jj,5)

      VarName='SH2O'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM,JS,JE,NSOIL)
       
      do l = 1, nsoil
       do j = jsta_2l, jend_2u
        do i = 1, im
            sh2o ( i, j, l ) = dum3d ( i, j, nsoil-l+1)
        end do
       end do
      end do 
      

      VarName='XICE'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
     
      do j = jsta_2l, jend_2u
        do i = 1, im
            SICE( i, j ) = dummy ( i, j )
        end do
       end do

!
! reading SMSTAV
      VarName='SMSTAV'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            SMSTAV ( i, j ) = dummy ( i, j )
        end do
       end do
!
! reading SURFACE RUNOFF 
      VarName='SFROFF'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            SSROFF ( i, j ) = dummy ( i, j )
        end do
       end do
!
! reading UNDERGROUND RUNOFF
      VarName='UDROFF'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            BGROFF ( i, j ) = dummy ( i, j )
        end do
       end do
! reading VEGETATION TYPE 
      VarName='IVGTYP'
      call getIVariable(fileName,DateStr,DataHandle,VarName,IDUMMY      &  
        ,IM,1,JM,1,IM,JS,JE,1)
!      print*,'IVGTYP at ',ii,jj,' = ',IDUMMY(ii,jj)
       do j = jsta_2l, jend_2u
        do i = 1, im
            IVGTYP ( i, j ) = idummy ( i, j ) 
        end do
       end do 
       
      VarName='ISLTYP' 
      call getIVariable(fileName,DateStr,DataHandle,VarName,IDUMMY      &
        ,IM,1,JM,1,IM,JS,JE,1)
      do j = jsta_2l, jend_2u
        do i = 1, im
            ISLTYP ( i, j ) = idummy ( i, j ) 
        end do
       end do
       print*,'MAX ISLTYP=', maxval(idummy)
       
      VarName='VEGFRA'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            VEGFRC ( i, j ) = dummy ( i, j )
        end do
       end do
!      print*,'VEGFRC at ',ii,jj,' = ',VEGFRC(ii,jj) 
 
      VarName='SFCEVP'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY2,      &
        IM,1,JM,1,IM,JS,JE,1)

      
      VarName='GRDFLX'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
      do j = jsta_2l, jend_2u
        do i = 1, im
            GRNFLX(I,J) = dummy ( i, j )
        end do
       end do    
 
      VarName='SFCEXC'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY2,      &
        IM,1,JM,1,IM,JS,JE,1)

      
      VarName='ACSNOW'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            ACSNOW ( i, j ) = dummy ( i, j )
        end do
       end do
       
      VarName='ACSNOM'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            ACSNOM ( i, j ) = dummy ( i, j )
        end do
       end do

      VarName='SNOW'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
     
      do j = jsta_2l, jend_2u
        do i = 1, im
            SNO ( i, j ) = dummy ( i, j )
        end do
       end do
     
      VarName='SNOWH'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)

      VarName='CANWAT'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            CMC ( i, j ) = dummy ( i, j )
        end do
       end do
      VarName='SST'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            SST ( i, j ) = dummy ( i, j )
        end do
       end do
!      print*,'SST at ',ii,jj,' = ',sst(ii,jj)      

!      VarName='WEASD'
!      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
!        IM,1,JM,1,IM,JS,JE,1)

!      VarName='TKE_MYJ'
!      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
!        IM,1,JM,1,IM,JS,JE,1)

      VarName='THZ0'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            THZ0 ( i, j ) = dummy ( i, j )
        end do
       end do
!      print*,'THZ0 at ',ii,jj,' = ',THZ0(ii,jj)

      VarName='Z0'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            Z0 ( i, j ) = dummy ( i, j )
        end do
       end do
!      print*,'Z0 at ',ii,jj,' = ',Z0(ii,jj)

      VarName='QZ0'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            QZ0 ( i, j ) = dummy ( i, j )
        end do
       end do
!      print*,'QZ0 at ',ii,jj,' = ',QZ0(ii,jj)
      VarName='UZ0'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            UZ0 ( i, j ) = dummy ( i, j )
        end do
       end do
!      print*,'UZ0 at ',ii,jj,' = ',UZ0(ii,jj)
      VarName='VZ0'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            VZ0 ( i, j ) = dummy ( i, j )
        end do
       end do
!      print*,'VZ0 at ',ii,jj,' = ',VZ0(ii,jj)
      VarName='QSFC'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            QS ( i, j ) = dummy ( i, j )
        end do
       end do
!      print*,'QS at ',ii,jj,' = ',QS(ii,jj)
      VarName='AKHS'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            AKHS ( i, j ) = dummy ( i, j )
        end do
       end do
      VarName='AKMS'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            AKMS ( i, j ) = dummy ( i, j )
        end do
       end do
       
      VarName='HTOP'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            HTOP ( i, j ) = float(LM)-dummy(i,j)+1.0
        end do
       end do
      VarName='HBOT'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            HBOT ( i, j ) = float(LM)-dummy(i,j)+1.0
        end do
       end do 
       
       VarName='CUPPT'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            CUPPT ( i, j ) = dummy ( i, j )
        end do
       end do

      if(imp_physics .eq. 5)then

      VarName='F_ICE_PHY'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
!      call getVariable(fileName,DateStr,DataHandle,'QCLOUD',DUM3D,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
            F_ICE ( i, j, l ) = dum3d ( i, j, l )
        end do
       end do
      end do

      VarName='F_RAIN_PHY'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
!      call getVariable(fileName,DateStr,DataHandle,'QCLOUD',DUM3D,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
            F_RAIN ( i, j, l ) = dum3d ( i, j, l )
        end do
       end do
      end do

      VarName='F_RIMEF_PHY'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUM3D,       &
        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
!      call getVariable(fileName,DateStr,DataHandle,'QCLOUD',DUM3D,
!        IM+1,1,JM+1,LM+1,IM,JS,JE,LM)
      do l = 1, lm
       do j = jsta_2l, jend_2u
        do i = 1, im
            F_RIMEF ( i, j, l ) = dum3d ( i, j, l )
        end do
       end do
      end do

      end if
!    
      VarName='MAPFAC_M'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
      do j = jsta_2l, jend_2u
        do i = 1, im
            MSFT ( i, j ) = dummy ( i, j ) 
        end do
       end do
       
      VarName='MAPFAC_U'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
      
      VarName='MAPFAC_V'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)


      VarName='F'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)

      VarName='E'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)

      VarName='SINALPHA'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
      
      VarName='COSALPHA'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)

! reading terrain height
      VarName='HGT'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            FIS ( i, j ) = dummy ( i, j ) * G
!            if(i.eq.80.and.j.eq.42)print*,'Debug: sample fis,zint='
!     1,dummy( i, j ),zint(i,j,lm+1)
        end do
       end do
!       print*,'FIS at ',ii,jj,ll,' = ',FIS(ii,jj)

        write(6,*) 'past getting of HGT'
!
!	In my version, variable is TSK (skin temp, not skin pot temp)
!
!mp      call getVariable(fileName,DateStr,DataHandle,'THSK',DUMMY,
      VarName='TSK'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            THS ( i, j ) = dummy ( i, j ) ! wait to convert to theta later 
            RADOT ( i, j ) = DUMMY(i,j)**4.0/STBOL    
        end do
       end do
!       print*,'THS at ',ii,jj,' = ',THS(ii,jj)
!
! reading p_top
      VarName='P_TOP'
      call getVariableB(fileName,DateStr,DataHandle,VarName,PT,         &
        1,1,1,1,1,1,1,1)
      print*,'P_TOP = ',PT
      DO I=1,IM
            DO J=JS,JE
                 PINT (I,J,LM+1) = PINT (I,J,LM+1)+PT
                 THS ( i, j ) = THS ( i, j )                            &
                             *(P1000/PINT(I,J,NINT(LMH(I,J))+1))**CAPA
                 PINT (I,J,1) = PT
                 ALPINT(I,J,LM+1)=ALOG(PINT(I,J,LM+1))
                 ALPINT(I,J,1)=ALOG(PINT(I,J,1))
            ENDDO
         ENDDO
!      print*,'PSFC at ',ii,jj,' = ',PINT (ii,jj,lm+1)
!      print*,'THS at ',ii,jj,' = ',THS(ii,jj)

      VarName='LAT_LL_T'
      call getVariableB(fileName,DateStr,DataHandle,VarName,LAT_LL_T,   &
        1,1,1,1,1,1,1,1)

      VarName='LAT_UL_T'
      call getVariableB(fileName,DateStr,DataHandle,VarName,LAT_UL_T,   &
        1,1,1,1,1,1,1,1)

      VarName='LAT_UR_T'
      call getVariableB(fileName,DateStr,DataHandle,VarName,LAT_UR_T,   &
        1,1,1,1,1,1,1,1)

      VarName='LAT_LR_T'
      call getVariableB(fileName,DateStr,DataHandle,VarName,LAT_LR_T,   &
        1,1,1,1,1,1,1,1)

      VarName='LON_LL_T'
      call getVariableB(fileName,DateStr,DataHandle,VarName,LON_LL_T,   &
        1,1,1,1,1,1,1,1)

      VarName='LON_UL_T'
      call getVariableB(fileName,DateStr,DataHandle,VarName,LON_UL_T,   &
        1,1,1,1,1,1,1,1)
     
      VarName='LON_UR_T'
      call getVariableB(fileName,DateStr,DataHandle,VarName,LON_UR_T,   &
        1,1,1,1,1,1,1,1)     

      VarName='LON_LR_T'
      call getVariableB(fileName,DateStr,DataHandle,VarName,LON_LR_T,   &
        1,1,1,1,1,1,1,1)
     
     
!C
!C RAINC is "ACCUMULATED TOTAL CUMULUS PRECIPITATION" 
!C RAINNC is "ACCUMULATED TOTAL GRID SCALE PRECIPITATION"

	write(6,*) 'getting RAINC'
      VarName='RAINC'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            CUPREC ( i, j ) = dummy ( i, j ) * 0.001
        end do
       end do
!       print*,'CUPREC at ',ii,jj,' = ',CUPREC(ii,jj)

      write(6,*) 'getting RAINNC'
      VarName='RAINNC'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            ANCPRC ( i, j ) = dummy ( i, j )* 0.001
	    ACPREC ( i, j ) = ANCPRC(I,J)+CUPREC(I,J)
        end do
       end do
!       print*,'ANCPRC at ',ii,jj,' = ',ANCPRC(ii,jj)
	write(6,*) 'past getting RAINNC'

      VarName='RAINCV'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            CPRATE ( i, j ) = dummy ( i, j )* 0.001
        end do
       end do
       
       VarName='RAINNCV'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY2,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            prec ( i, j ) = (dummy ( i, j )+dummy2(i,j))* 0.001
        end do
       end do

!      VarName='RAINBL'
!      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
!        IM,1,JM,1,IM,JS,JE,1)

      VarName='SWDOWN'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)

      VarName='GSW'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY2,      &
        IM,1,JM,1,IM,JS,JE,1)

! Seperate NET solar into upward and downward when we have albedo later 
!       do j = jsta_2l, jend_2u
!        do i = 1, im
! HCHUANG: GSW is actually net downward shortwave in ncar wrf	
!            RSWIN ( i, j ) = dummy2 ( i, j )/(1.0-albedo(i,j))
!            RSWOUT ( i, j ) = RSWIN ( i, j ) - dummy2 ( i, j )
!        end do
!       end do
! ncar wrf does not output zenith angle so make czen=czmean so that
! RSWIN can be output normally in SURFCE
       do j = jsta_2l, jend_2u
        do i = 1, im
             CZEN ( i, j ) = 1.0 
             CZMEAN ( i, j ) = CZEN ( i, j )
        end do
       end do       
       
      VarName='GLW'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            RLWIN ( i, j ) = dummy ( i, j )
        end do
       end do
! ncar wrf does not output sigt4 so make sig4=sigma*tlmh**4
       do j = jsta_2l, jend_2u
        do i = 1, im
             TLMH=T(I,J,NINT(LMH(I,J)))
             SIGT4 ( i, j ) =  5.67E-8*TLMH*TLMH*TLMH*TLMH
        end do
       end do
       
! NCAR WRF does not output accumulated fluxes so set the bitmap of these fluxes to 0
      do j = jsta_2l, jend_2u
        do i = 1, im
	   RLWTOA(I,J)=SPVAL
	   RSWINC(I,J)=SPVAL
           ASWIN(I,J)=SPVAL  
	   ASWOUT(I,J)=SPVAL
	   ALWIN(I,J)=SPVAL
	   ALWOUT(I,J)=SPVAL
	   ALWTOA(I,J)=SPVAL
	   ASWTOA(I,J)=SPVAL
	   ARDLW=1.0
	   ARDSW=1.0
	   NRDLW=1
	   NRDSW=1
        end do
       end do

!
      VarName='XLAT'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            GDLAT ( i, j ) = dummy ( i, j )
! compute F = 2*omg*sin(xlat)
            f(i,j) = 1.454441e-4*sin(gdlat(i,j)*DTR)
        end do
       end do
! pos north
      print*,'read past GDLAT'
!      print*,'GDLAT at ',ii,jj,' = ',GDLAT(ii,jj)

      VarName='XLONG'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            GDLON ( i, j ) = dummy ( i, j )
!            if(abs(GDLAT(i,j)-20.0).lt.0.5 .and. abs(GDLON(I,J)
!     1      +157.0).lt.5.)print*
!     2      ,'Debug:I,J,GDLON,GDLAT,SM,HGT,psfc= ',i,j,GDLON(i,j)
!     3      ,GDLAT(i,j),SM(i,j),FIS(i,j)/G,PINT(I,j,lm+1)
        end do
       end do
!       print*,'GDLON at ',ii,jj,' = ',GDLON(ii,jj)
       print*,'read past GDLON'

      VarName='ALBEDO'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            ALBEDO ( i, j ) = dummy ( i, j )
! HCHUANG: GSW is actually net downward shortwave in ncar wrf
            RSWIN ( i, j ) = dummy2 ( i, j )/(1.0-albedo(i,j))
            RSWOUT ( i, j ) = RSWIN ( i, j ) - dummy2 ( i, j )
        end do
       end do

      VarName='TMN'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            TG ( i, j ) = dummy ( i, j )
            SOILTB ( i, j ) = dummy ( i, j )
        end do
       end do
!
! XLAND 1 land 2 sea
      VarName='XLAND'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            SM ( i, j ) = dummy ( i, j ) - 1.0
        end do
       end do
       
      VarName='UST'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            USTAR ( i, j ) = dummy ( i, j ) 
        end do
       end do 

      VarName='RMOL'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)

      VarName='PBLH'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            PBLH ( i, j ) = dummy ( i, j ) 
        end do
       end do

!
      VarName='HFX'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            TWBS( i, j ) = dummy ( i, j )
        end do
       end do
      VarName='QFX'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       
       VarName='LH'   
       call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
     &   IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            QWBS(I,J) = dummy ( i, j )
        end do
       end do

! NCAR WRF does not output accumulated fluxes so bitmask out these fields
      do j = jsta_2l, jend_2u
        do i = 1, im
           SFCSHX(I,J)=SPVAL  
	   SFCLHX(I,J)=SPVAL
	   SUBSHX(I,J)=SPVAL
	   SNOPCX(I,J)=SPVAL
	   SFCUVX(I,J)=SPVAL
	   POTEVP(I,J)=SPVAL
	   NCFRCV(I,J)=SPVAL
	   NCFRST(I,J)=SPVAL
	   ASRFC=1.0
	   NSRFC=1
        end do
       end do

      VarName='SNOWC'
      call getVariableB(fileName,DateStr,DataHandle,VarName,DUMMY,      &
        IM,1,JM,1,IM,JS,JE,1)
       do j = jsta_2l, jend_2u
        do i = 1, im
            PCTSNO( i, j ) = dummy ( i, j )
        end do
       end do
! pos east
       call collect_loc(gdlat,dummy)
       if(me.eq.0)then
        latstart=nint(dummy(1,1)*1000.)
        latlast=nint(dummy(im,jm)*1000.)
       end if
       write(6,*) 'laststart,latlast B calling bcast=',latstart,latlast
       call mpi_bcast(latstart,1,MPI_INTEGER,0,mpi_comm_comp,irtn)
       call mpi_bcast(latlast,1,MPI_INTEGER,0,mpi_comm_comp,irtn)
       write(6,*) 'laststart,latlast A calling bcast=',latstart,latlast
       call collect_loc(gdlon,dummy)
       if(me.eq.0)then
        lonstart=nint(dummy(1,1)*1000.)
        lonlast=nint(dummy(im,jm)*1000.)
       end if
       write(6,*)'lonstart,lonlast B calling bcast=',lonstart,lonlast
       call mpi_bcast(lonstart,1,MPI_INTEGER,0,mpi_comm_comp,irtn)
       call mpi_bcast(lonlast,1,MPI_INTEGER,0,mpi_comm_comp,irtn)
       write(6,*)'lonstart,lonlast A calling bcast=',lonstart,lonlast
!
!        ncdump -h

!!
!! 
!!
        write(6,*) 'filename in INITPOST=', filename,' is'

!	status=nf_open(filename,NF_NOWRITE,ncid)
!	        write(6,*) 'returned ncid= ', ncid
!        status=nf_get_att_real(ncid,varid,'DX',tmp)
!	dxval=int(tmp)
!        status=nf_get_att_real(ncid,varid,'DY',tmp)
!	dyval=int(tmp)
!        status=nf_get_att_real(ncid,varid,'CEN_LAT',tmp)
!	cenlat=int(1000.*tmp)
!        status=nf_get_att_real(ncid,varid,'CEN_LON',tmp)
!	cenlon=int(1000.*tmp)
!        status=nf_get_att_real(ncid,varid,'TRUELAT1',tmp)
!	truelat1=int(1000.*tmp)
!        status=nf_get_att_real(ncid,varid,'TRUELAT2',tmp)
!	truelat2=int(1000.*tmp)
!        status=nf_get_att_real(ncid,varid,'MAP_PROJ',tmp)
!        maptype=int(tmp)
!	status=nf_close(ncid)

!	dxval=30000.
! 	dyval=30000.
!
!        write(6,*) 'dxval= ', dxval
!        write(6,*) 'dyval= ', dyval
!        write(6,*) 'cenlat= ', cenlat
!        write(6,*) 'cenlon= ', cenlon
!        write(6,*) 'truelat1= ', truelat1
!        write(6,*) 'truelat2= ', truelat2
!        write(6,*) 'maptype is ', maptype
!

!MEB not sure how to get these 
       do j = jsta_2l, jend_2u
        do i = 1, im
            DX ( i, j ) = dxval/MSFT(I,J)
            DY ( i, j ) = dyval/MSFT(I,J)
        end do
       end do
!MEB not sure how to get these 

! close up shop
      call ext_int_ioclose ( DataHandle, Status )

! generate look up table for lifted parcel calculations

      THL=210.
      PLQ=70000.

      CALL TABLE(PTBL,TTBL,PT,                                          &  
                RDQ,RDTH,RDP,RDTHE,PL,THL,QS0,SQS,STHE,THE0)

      CALL TABLEQ(TTBLQ,RDPQ,RDTHEQ,PLQ,THL,STHEQ,THE0Q)


!     
!     
      IF(ME.EQ.0)THEN
        WRITE(6,*)'  SPL (POSTED PRESSURE LEVELS) BELOW: '
        WRITE(6,51) (SPL(L),L=1,LSM)
   50   FORMAT(14(F4.1,1X))
   51   FORMAT(8(F8.1,1X))
      ENDIF
!     
!     COMPUTE DERIVED TIME STEPPING CONSTANTS.
!
!MEB need to get DT
!      DT = 120. !MEB need to get DT
      NPHS = 1  !CHUANG SET IT TO 1 BECAUSE ALL THE INST PRECIP ARE ACCUMULATED 1 TIME STEP
      DTQ2 = DT * NPHS  !MEB need to get physics DT
      TSPH = 3600./DT   !MEB need to get DT
!MEB need to get DT

! Randomly specify accumulation period because WRF EM does not
! output accumulation fluxes yet and accumulated fluxes are bit
! masked out

      TSRFC=1.0
      TRDLW=1.0
      TRDSW=1.0
      THEAT=1.0
      TCLOD=1.0
      TPREC=float(ifhr)  ! WRF EM does not empty precip buket at all
      
!how am i going to get this information?
!      NPREC  = INT(TPREC *TSPH+D50)
!      NHEAT  = INT(THEAT *TSPH+D50)
!      NCLOD  = INT(TCLOD *TSPH+D50)
!      NRDSW  = INT(TRDSW *TSPH+D50)
!      NRDLW  = INT(TRDLW *TSPH+D50)
!      NSRFC  = INT(TSRFC *TSPH+D50)
!how am i going to get this information?
!     
!     IF(ME.EQ.0)THEN
!       WRITE(6,*)' '
!       WRITE(6,*)'DERIVED TIME STEPPING CONSTANTS'
!       WRITE(6,*)' NPREC,NHEAT,NSRFC :  ',NPREC,NHEAT,NSRFC
!       WRITE(6,*)' NCLOD,NRDSW,NRDLW :  ',NCLOD,NRDSW,NRDLW
!     ENDIF
!
!     COMPUTE DERIVED MAP OUTPUT CONSTANTS.
      DO L = 1,LSM
         ALSL(L) = ALOG(SPL(L))
      END DO
!
!HC WRITE IGDS OUT FOR WEIGHTMAKER TO READ IN AS KGDSIN
        if(me.eq.0)then
        print*,'writing out igds'
        igdout=110
!        open(igdout,file='griddef.out',form='unformatted'
!     +  ,status='unknown')
        if(maptype .eq. 1)THEN  ! Lambert conformal
          WRITE(igdout)3
          WRITE(6,*)'igd(1)=',3
          WRITE(igdout)im
          WRITE(igdout)jm
          WRITE(igdout)LATSTART
          WRITE(igdout)LONSTART
          WRITE(igdout)8
!          WRITE(igdout)CENLON
          WRITE(igdout)STANDLON
          WRITE(igdout)DXVAL
          WRITE(igdout)DYVAL
          WRITE(igdout)0
          WRITE(igdout)64
          WRITE(igdout)TRUELAT2
          WRITE(igdout)TRUELAT1
          WRITE(igdout)255
        ELSE IF(MAPTYPE .EQ. 2)THEN  !Polar stereographic
          WRITE(igdout)5
          WRITE(igdout)im
          WRITE(igdout)jm
          WRITE(igdout)LATSTART
          WRITE(igdout)LONSTART
          WRITE(igdout)8
          WRITE(igdout)CENLON
          WRITE(igdout)DXVAL
          WRITE(igdout)DYVAL
          WRITE(igdout)0
          WRITE(igdout)64
          WRITE(igdout)TRUELAT2  !Assume projection at +-90
          WRITE(igdout)TRUELAT1
          WRITE(igdout)255
        ELSE IF(MAPTYPE .EQ. 3)THEN  !Mercator
          WRITE(igdout)1
          WRITE(igdout)im
          WRITE(igdout)jm
          WRITE(igdout)LATSTART
          WRITE(igdout)LONSTART
          WRITE(igdout)8
          WRITE(igdout)latlast
          WRITE(igdout)lonlast
          WRITE(igdout)TRUELAT1
          WRITE(igdout)0
          WRITE(igdout)64
          WRITE(igdout)DXVAL
          WRITE(igdout)DYVAL
          WRITE(igdout)255
        END IF
        end if
!     
!

      RETURN
      END