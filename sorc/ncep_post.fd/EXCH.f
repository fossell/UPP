!> @file
!
!> SUBPROGRAM:    EXCH        EXCHANGE ONE HALO ROW
!!   PRGRMMR: TUCCILLO        ORG: IBM
!!
!! ABSTRACT:
!!     EXCHANGE ONE HALO ROW
!!
!! PROGRAM HISTORY LOG:
!!   00-01-06  TUCCILLO - ORIGINAL
!!
!! USAGE:    CALL EXCH(A)
!!   INPUT ARGUMENT LIST:
!!      A - ARRAY TO HAVE HALOS EXCHANGED
!!
!!   OUTPUT ARGUMENT LIST:
!!      A - ARRAY WITH HALOS EXCHANGED
!!
!!   OUTPUT FILES:
!!     STDOUT  - RUN TIME STANDARD OUT.
!!
!!   SUBPROGRAMS CALLED:
!!       MPI_SENDRECV
!!     UTILITIES:
!!       NONE
!!     LIBRARY:
!!       COMMON - CTLBLK.comm
!!
!@PROCESS NOCHECK
!
!--- The 1st line is an inlined compiler directive that turns off -qcheck
!    during compilation, even if it's specified as a compiler option in the
!    makefile (Tuccillo, personal communication;  Ferrier, Feb '02).
!
      SUBROUTINE EXCH(A)
!      use ifcore
      

      use ctlblk_mod, only: num_procs, jend, iup, jsta, idn, mpi_comm_comp, im,&
          icoords,ibcoords,bufs,ibufs,me,numx, &   ! GWV TMP

              jsta_2l, jend_2u,ileft,iright,ista_2l,iend_2u,ista,iend,jm,modelname
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      implicit none
!     
      include 'mpif.h'
!
!      real,intent(inout) :: a ( im,jsta_2l:jend_2u )
       real,intent(inout) :: a ( ista_2l:iend_2u,jsta_2l:jend_2u )
       real, allocatable :: coll(:), colr(:)
       integer, allocatable :: icoll(:), icolr(:)
       real, allocatable ::  rpole(:),rpoles(:,:) 
      
       
      integer status(MPI_STATUS_SIZE)
      integer ierr, jstam1, jendp1,j
      integer size,ubound,lbound
      integer msglenl, msglenr
      integer i,ii,jj, ibl,ibu,jbl,jbu,icc,jcc !GWV
      integer iwest,ieast
      allocate(coll(jm))
      allocate(colr(jm))
      allocate(icolr(jm)) !GWV
      allocate(icoll(jm)) !GWV
      allocate(rpole(ista:iend)) !GWV
      allocate(rpoles(im,2)) !GWV
      ibl=max(ista-1,1)
      ibu=min(im,iend+1)
      jbu=min(jm,jend+1)
      jbl=max(jsta-1,1)
!

!     write(0,*) 'mype=',me,'num_procs=',num_procs,'im=',im,'jsta_2l=', &
!             jsta_2l,'jend_2u=',jend_2u,'jend=',jend,'iup=',iup,'jsta=', &
!             jsta,'idn=',idn
      if ( num_procs <= 1 ) return
!
!  for global model apply cyclic boundary condition

                IF(MODELNAME == 'GFS') then
                  print *,' GWVX CYCLIC BC APPLIED'
                  if(ileft .eq. MPI_PROC_NULL)  iwest=1         ! get eastern bc from western boundary of full domain
                  if(iright .eq. MPI_PROC_NULL)  ieast=1        ! get western bc from eastern boundary of full domain
                  if(ileft .eq. MPI_PROC_NULL)  ileft=me+(numx-1) !GWVB
                 if(iright .eq. MPI_PROC_NULL)  iright=(me-numx) +1  !GWVB
                endif

      jstam1 = max(jsta_2l,jsta-1)                        ! Moorthi
!  send last row to iup's first row+  and receive first row-  from idn's last row
      call mpi_sendrecv(a(ista,jend),iend-ista+1,MPI_REAL,iup,1,             &
     &                  a(ista,jstam1),iend-ista+1,MPI_REAL,idn,1,           &
     &                  MPI_COMM_COMP,status,ierr)
      if ( ierr /= 0 ) then
         print *, ' problem with second sendrecv in exch, ierr = ',ierr
         stop
      endif
          call mpi_sendrecv(ibcoords(ista,jend),iend-ista+1,MPI_INTEGER,iup,1,             &
         &                  ibcoords(ista,jstam1),iend-ista+1,MPI_INTEGER,idn,1,           &
         &                  MPI_COMM_COMP,status,ierr)
      if ( ierr /= 0 ) then
         print *, ' problem with second sendrecv in exch, ierr = ',ierr
         stop
      endif
            do i=ista,iend
            ii=ibcoords(i,jstam1)/10000
            jj=ibcoords(i,jstam1)-(ii*10000)
            if(ii .ne. i .or. jj .ne. jstam1 ) print *,' GWVX JEXCH CHECK FAIL ',ii,jj,ibcoords(i,jstam1),i
            end do
!  build the I columns to send and receive
 902  format(' GWVX EXCH BOUNDS ',18i8)
      msglenl=jend-jsta+1
      msglenr=jend-jsta+1
        if(iright .lt. 0) msglenr=1
        if(ileft .lt. 0) msglenl=1
!gwv     write(0,902),lbound(a),ubound(a),lbound(coll),ubound(coll),ista,jsta,jend,jend-jsta+1,msglenl,msglenr
     do j=jsta,jend
     coll(j)=a(ista,j)
       icoll(j)=icoords(ista,j) !GWV TMP
     end do
      call mpi_barrier(mpi_comm_comp,ierr)
       
!  send first col    to  ileft  last  col+  and receive last  col+ from ileft first col 
      call mpi_sendrecv(coll(jsta),msglenl    ,MPI_REAL,ileft,1,             &
    &                  colr(jsta),msglenr    ,MPI_REAL,iright,1,           &
    &                  MPI_COMM_COMP,status,ierr)
      if ( ierr /= 0 ) then
         print *, ' problem with second sendrecv in exch, ierr = ',ierr
         stop
      endif
          call mpi_sendrecv(icoll(jsta),msglenl    ,MPI_INTEGER,ileft,1,             & !GWV TMP
        &                  icolr(jsta),msglenr    ,MPI_INTEGER,iright,1,           & !GWV TMP
        &                  MPI_COMM_COMP,status,ierr)
      if ( ierr /= 0 ) then
         print *, ' problem with second sendrecv in exch, ierr = ',ierr
         stop
      endif
     if(iright .ge. 0) then
        do j=jsta,jend
        a(iend+1,j)=colr(j)
            ibcoords(iend+1,j)=icolr(j)  !GWV TMP
               ii=ibcoords(iend+1,j)/10000
                   jj=ibcoords( iend+1,j)-(ii*10000)
!                 if(iend+1 .eq. 3073) write(0,*) ' GWVX IBCOLL SETT2 ',iend+1,j,icolr(j),ii,jj !GWVX TMP
!                 if(iend+1 .eq. 3073 .and. ii  .ne. 1) write(0,*) ' GWVX IBCOLL FAILED SETT2 ',iend+1,j,icolr(j),ii,jj !GWVX TMP
              if( j .ne. jj .or. ii .ne. iend+1 .and. ii .ne. im .and. ii .ne. 1) &
             write(0,921) j,iend+1,ii,jj,ibcoords(iend+1,j),' GWVX IEXCH COORD FAIL j,iend+1,ii,jj,ibcoord '
 921   format(5i10,a50)
! 
        
        end do
     endif
     
!      print *,'mype=',me,'in EXCH, after first mpi_sendrecv'
      if ( ierr /= 0 ) then
         print *, ' problem with first sendrecv in exch, ierr = ',ierr
         stop 6667
      end if
      jendp1 = min(jend+1,jend_2u)                          ! Moorthi
!GWV.  change from full im row exchange to iend-ista+1 subrow exchange,
!GWVt of 2D decomp
     do j=jsta,jend
     colr(j)=a(iend,j)
     icolr(j)=icoords(iend,j) !GWV TMP
     end do
!  send first row   to idown's last row+  and receive last row+  from iup's first row
      call mpi_sendrecv(a(ista,jsta),iend-ista+1,MPI_REAL,idn,1,             &
     &                  a(ista,jendp1),iend-ista+1,MPI_REAL,iup,1,           &
     &                  MPI_COMM_COMP,status,ierr)
      if ( ierr /= 0 ) then
         print *, ' problem with second sendrecv in exch, ierr = ',ierr
         stop
      endif
      call mpi_sendrecv(ibcoords(ista,jsta),iend-ista+1,MPI_INTEGER,idn,1,             &
     &                  ibcoords(ista,jendp1),iend-ista+1,MPI_INTEGER,iup,1,           &
     &                  MPI_COMM_COMP,status,ierr)
      if ( ierr /= 0 ) then
         print *, ' problem with second sendrecv in exch, ierr = ',ierr
         stop
      endif
!  send last col    to  iright first col-  and receive first col- from ileft last col 
      call mpi_sendrecv(colr(jsta),msglenr    ,MPI_REAL,iright,1 ,            &
    &                  coll(jsta),msglenl    ,MPI_REAL,ileft ,1,           &
    &                  MPI_COMM_COMP,status,ierr)
      if ( ierr /= 0 ) then
         print *, ' problem with second sendrecv in exch, ierr = ',ierr
         stop
      endif
          call mpi_sendrecv(icolr(jsta),msglenr    ,MPI_integer,iright,1 ,            &
        &                  icoll(jsta),msglenl    ,MPI_integer,ileft ,1,           &
        &                  MPI_COMM_COMP,status,ierr)
      if ( ierr /= 0 ) then
         print *, ' problem with second sendrecv in exch, ierr = ',ierr
         stop
      endif
     if(ileft .ge. 0) then
        do j=jsta,jend
        a(ista-1,j)=coll(j)
                ibcoords(ista-1,j)=icoll(j)  !GWV TMP
!                write(0,*) ' GWVX IBCOLL SETT ',ista-1,j,icoll(j)
               ii=ibcoords(ista-1,j)/10000
                   jj=ibcoords( ista-1,j)-(ii*10000)
              if( j .ne. jj .or. ii .ne. ista-1 .and. ii .ne. im .and. ii .ne. 1) &
        write(0,921) j,ista-1,ii,jj,ibcoords(ista-1,j),' GWVX EXCH COORD FAIL j,ista-1,ii,jj,ibcoord '
        end do
     endif
!  interior check
              do j=jsta,jend
              do i=ista,iend
               ii=ibcoords(i,j)/10000
                   jj=ibcoords( i,j)-(ii*10000)
           if(ii .ne. i .or. jj .ne. j) write(0,151) 'GWVX INFAILED IJ ',i,j,ibcoords(i,j),ibl,jbl,ibu,jbu
            end do
            end do

!!   corner points.   After the exchanges above, corner points are replicated in
!    neighbour halos so we can get them from the neighbors rather than
!    calculating more corner neighbor numbers  
! A(ista-1,jsta-1) is in the ileft     a(iend,jsta-1) location 
! A(ista-1,jend+1) is in the ileft     a(iend,jend+1) location 
! A(iend+1,jsta-1) is in the iright     a(ista,jsta-1) location 
! A(iend+1,jend+1) is in the iright    a(ista,jend+1) location 
!GWVx      ibl=max(ista-1,1)
!GWVx      ibu=min(im,iend+1)

      ibl=max(ista-1,0)
      ibu=min(im+1,iend+1)
      jbu=min(jm,jend+1)
      jbl=max(jsta-1,1)

      call mpi_sendrecv(a(iend,jbl   ),1,    MPI_REAL,iright,1 ,            &
    &                  a(ibl   ,jbl   ),1,   MPI_REAL,ileft ,1,           &
    &                  MPI_COMM_COMP,status,ierr)
      if ( ierr /= 0 ) then
         print *, ' problem with second sendrecv in exch, ierr = ',ierr
         stop
         endif

      call mpi_sendrecv(a(iend,jbu   ),1,    MPI_REAL,iright,1 ,            &
    &                  a(ibl   ,jbu   ),1,   MPI_REAL,ileft ,1,           &
    &                  MPI_COMM_COMP,status,ierr)
      if ( ierr /= 0 ) then
         print *, ' problem with second sendrecv in exch, ierr = ',ierr
         stop
         endif
      call mpi_sendrecv(a(ista,jbl   ),1,    MPI_REAL,ileft ,1,            &
    &                  a(ibu   ,jbl   ),1,   MPI_REAL,iright,1,           &
    &                  MPI_COMM_COMP,status,ierr)
      if ( ierr /= 0 ) then
         print *, ' problem with second sendrecv in exch, ierr = ',ierr
         stop
         endif

      call mpi_sendrecv(a(ista,jbu   ),1,    MPI_REAL,ileft ,1 ,            &
    &                  a(ibu   ,jbu   ),1,   MPI_REAL,iright,1,           &
    &                  MPI_COMM_COMP,status,ierr)
      if ( ierr /= 0 ) then
         print *, ' problem with second sendrecv in exch, ierr = ',ierr
         stop
      endif
!GWV TEST       
 139    format(a20,5(i10,i6,i6,'<>'))

      call mpi_sendrecv(ibcoords(iend,jbl   ),1    ,MPI_INTEGER,iright,1 ,            &
    &                  ibcoords(ibl   ,jbl   ),1   ,MPI_INTEGER,ileft ,1,           &
    &                  MPI_COMM_COMP,status,ierr)

      call mpi_sendrecv(ibcoords(iend,jbu   ),1    ,MPI_INTEGER,iright,1,            &
    &                  ibcoords(ibl   ,jbu   ),1   ,MPI_INTEGER,ileft ,1,           &
    &                  MPI_COMM_COMP,status,ierr)
      call mpi_sendrecv(ibcoords(ista,jbl   ),1    ,MPI_INTEGER,ileft ,1,            &
    &                  ibcoords(ibu   ,jbl   ),1   ,MPI_INTEGER,iright,1,           &
    &                  MPI_COMM_COMP,status,ierr)
      call mpi_sendrecv(ibcoords(ista,jbu   ),1    ,MPI_INTEGER,ileft ,1 ,            &
    &                  ibcoords(ibu   ,jbu   ),1   ,MPI_INTEGER,iright,1,        &
                       MPI_COMM_COMP,status,ierr)
!    corner check for coordnates
              icc=ibl
              jcc=jbl
              ii=ibcoords(icc,jcc)/10000
              jj=ibcoords(icc,jcc)-(ii*10000)
!              if(ii .ne. icc .or. jj .ne. jcc .and. icc .ne. 0 ) write(0,151) ' CORNER FAIL ilb  ll ',icc,jcc,ibcoords(icc,jcc),ii,jj
               if(ii .ne. icc .and. icc .ne. 0) write(0,151) ' CORNER FAILI ilb  ll ',icc,jcc,ibcoords(icc,jcc),ii,jj
               if( jj .ne. jcc)  write(0,151) ' CORNER FAILJ ilb  ll ',icc,jcc,ibcoords(icc,jcc),ii,jj



              icc=ibu
              jcc=jbl
              ii=ibcoords(icc,jcc)/10000
              jj=ibcoords(icc,jcc)-(ii*10000)
!              if(ii .ne. icc .or. jj .ne. jcc .and. icc .ne. im+1 ) write(0,151) ' CORNER FAIL ilb ul  ',icc,jcc,ibcoords(icc,jcc),ii,jj
              if(ii .ne. icc .and. icc .ne. im+1 ) write(0,151) ' CORNER FAILI ilb ul  ',icc,jcc,ibcoords(icc,jcc),ii,jj
              if( jj .ne. jcc  ) write(0,151) ' CORNER FAILJ ilb ul  ',icc,jcc,ibcoords(icc,jcc),ii,jj

              icc=ibu
              jcc=jbu
              ii=ibcoords(icc,jcc)/10000
              jj=ibcoords(icc,jcc)-(ii*10000)
              if(ii .ne. icc  .and. icc .ne. im+1) write(0,151) ' CORNER FAILI ilb uu  ',icc,jcc,ibcoords(icc,jcc),ii,jj
              if( jj .ne. jcc  ) write(0,151) ' CORNER FAILJ ilb ul  ',icc,jcc,ibcoords(icc,jcc),ii,jj

              icc=ibl
              jcc=jbu
              ii=ibcoords(icc,jcc)/10000.
              jj=ibcoords(icc,jcc)-(ii*10000)
              if(ii .ne. icc  .and. icc .ne. 0 ) write(0,151) ' CORNER FAILI ilb lu  ',icc,jcc,ibcoords(icc,jcc),ii,jj
              if( jj .ne. jcc  ) write(0,151) ' CORNER FAILJ ilb ul  ',icc,jcc,ibcoords(icc,jcc),ii,jj

              
       if(ileft .ge. 0) then
!      write(0,119) ileft,me,ibcoords(ista-1,jend+1),ibcoords(ista-1,jend-1),ista-1,jend-1,jend+1 !GWVX
 119  format(' GWX LEFT EXCHANGE ileft,me,ibcoords(ista-1,jend+1),ibcoords(ista-1,jend-1),ista-1,jend-1,jend+1', &
      10i10)                                                                           
       endif
       if(iright .ge. 0) then
 !     write(0,129) iright,me,ibcoords(ista+1,jend+1),ibcoords(ista+1,jend-1),ista-1,jend-1,jend+1 !GWVX
 129  format(' GWX RIGHT  EXCHANGE iright,me,ibcoords(ista+1,jend+1),ibcoords(ista-1,jend+1),ista-1,jend-1,jend+1', &
      10i10)                                                                           
       endif
!  interior check
              do j=jsta,jend
              do i=ista,iend
               ii=ibcoords(i,j)/10000
                   jj=ibcoords( i,j)-(ii*10000)
           if(ii .ne. i .or. jj .ne. j) write(0,151) 'GWVX FAILED IJ ',i,j,ibcoords(i,j),ibl,jbl,ibu,jbu
 151   format(a70,10i10)
            end do
            end do 
!bounds check
! first check top and bottom halo rows
              j=jbu 
              do i=ista,iend
               ii=ibcoords(i,j)/10000
                   jj=ibcoords( i,j)-(ii*10000)
           if(ii .ne. i .or. jj .ne. j) write(0,151) 'GWVX FAILEDI JBU IJ ',i,j,ibcoords(i,j),ibl,jbl,ibu,jbu
            end do
              j=jbl
              do i=ista,iend
               ii=ibcoords(i,j)/10000
                   jj=ibcoords( i,j)-(ii*10000)
           if(ii .ne. i .or. jj .ne. j) write(0,151) 'GWVX FAILEDI JBL IJ ',i,j,ibcoords(i,j),ibl,jbl,ibu,jbu
            end do
! second and last, check left and right halo columns
              i=ibl
              do j=jsta,jend
               ii=ibcoords(i,j)/10000
                   jj=ibcoords( i,j)-(ii*10000)
           if(ii .ne. i .and. ii .ne. im  .or. jj .ne. j) write(0,151) 'GWVX FAILED IBL IJ ',ii,i,j,ibcoords(i,j),ibl,jbl,ibu,jbu
            end do
              i=ibu
              do j=jsta,jend
               ii=ibcoords(i,j)/10000
                   jj=ibcoords( i,j)-(ii*10000)
           if(ii .ne. i .and. ii .ne. 1  .or. jj .ne. j) write(0,151) 'GWVX FAILED IBU ii i j ibcoords ibl,jbl,ibu,jbu',ii,i,j,ibcoords(i,j),ibl,jbl,ibu,jbu
            end do
! end halo checks 
      if ( ierr /= 0 ) then
         print *, ' problem with second sendrecv in exch, ierr = ',ierr
         stop
      end if
           call mpi_barrier(mpi_comm_comp,ierr)
!           write(0,*) ' GWVX END EXCHHH '
!
      end

!!@PROCESS NOCHECK
!
!--- The 1st line is an inlined compiler directive that turns off -qcheck
!    during compilation, even if it's specified as a compiler option in the
!    makefile (Tuccillo, personal communication;  Ferrier, Feb '02).
!
      subroutine exch_f(a)
 
      use ctlblk_mod, only: num_procs, jend, iup, jsta, idn,    &
     &                      mpi_comm_comp, im, jsta_2l, jend_2u
!- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
      implicit none
!
      include 'mpif.h'
!
      real,intent(inout) :: a ( im,jsta_2l:jend_2u )
      integer status(MPI_STATUS_SIZE)
      integer ierr, jstam1, jendp1
!        write(0,*) ' called EXCH_F GWVX'
!
      if ( num_procs == 1 ) return
!
      jstam1 = max(jsta_2l,jsta-1)                       ! Moorthi
      call mpi_sendrecv(a(1,jend),im,MPI_REAL,iup,1,           &
     &                  a(1,jstam1),im,MPI_REAL,idn,1,         &
     &                  MPI_COMM_COMP,status,ierr)
      if ( ierr /= 0 ) then
         print *, ' problem with first sendrecv in exch, ierr = ',ierr
         stop
      end if
      jendp1=min(jend+1,jend_2u)                         ! Moorthi
      call mpi_sendrecv(a(1,jsta),im,MPI_REAL,idn,1,           &
     &                  a(1,jendp1),im,MPI_REAL,iup,1,         &
     &                  MPI_COMM_COMP,status,ierr)
      if ( ierr /= 0 ) then
         print *, ' problem with second sendrecv in exch, ierr = ',ierr
         stop
      end if
!
      end

