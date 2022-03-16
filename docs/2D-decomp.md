# 2-D Decomposition Overview

**Author:** George Vandenberghe

**Date:** March 2022

The 1D decomposition can read state from a model forecast  file, either by reading on rank 0
and scattering,  or by doing MPI_IO on the model history file using either nemsio, sigio,
or netcdf serial or parallel I/O.  Very old
post tags  also implement the more primitive full state broadcast or (a
performance bug rectified 10/17) read the entire state on all tasks.
This is mentioned in case a very old tag is encountered.  The 2D decomposition
only supports MPI_IO for the general 2D case but all I/O methods remain
supported for the 1D special case of the 2D code.   This 1D special case
works for all cases currently supported by older 1D tags and branches.

to repeat, ONLY 2D NETCDF PARALLEL I/O WILL  BE SUPPORTED FOR THE
GENERAL CASE OF 2D DECOMPOSITION.

****************************   2D design enhancements   ************************

 The 2D decomposition operates on subdomains with some latitudes and
 some longitudes.  The subdomains are lonlat rectangles rather than
 strips.   This means state must be chopped into pieces in any
 scatter operation and the pieces reassembled in any gather
 operation that requires a continuous in memory state.  I/O and halo
 exchanges both require significantly more bookkeeping.


 The structural changes needed for the 2D decomposition are
 implemented in MPI_FIRST.f   and CTLBLK.f!   CTLBLK.f contains
 numerous additional variables describing left and right domain
 boundaries.  Many additional changes are also implemented in EXCH.f
 to support 2D halos.  Many additional routines required addition of
 the longitude subdomain limits but changes to the layouts are
 handled in CTLBLK.f and the "many additional routines" do not
 require additional changes when subdomain shapes are changed and
 have not been a trouble point.


 Both MPI_FIRST and EXCH.f contain significant additional test code
 to exchange arrays containing grid coordinates and ensure EXACT
 matches for all exchanges before the domain exchanges are
 performed. This is intended to trap errors in the larger variety of
 2D decomposition layouts that are possible and most of it can
 eventually be removed or made conditional at build and run time.


The following is found in CTLBLK.f and shared in the rest of UPP
through use of CTLBLK.mod

  im integer   full longitude domain
  jm integer  full latitude domain

  jsta integer   start  latitude  on a task subdomain
  jend integer   end    latitude  on a task subdomain
  ista integer   start  longitude on a task subdomain
  iend integer   end    longitude on a task subdomain

  ista_2l integer start longitude -2 of the subdomain
  iend_2u integer end   longitude +2 of the subdomain
  jsta_2l integer start latitude  -2 of the subdomain
  jend_2u integer end   latitude  +2 of the subdomain

The shape of the subdomain is ista_2l:iend_2u,jsta_2l:jend_2u so it includes the halos although the halos are not populated until exhange is done in EXCH.f because of halos we need more bounds defined


  jsta_m     single latitude below begin latitude of subdomain.
  jend_m     single latitude above end latitude of subdomain
  jsta_m2    second latitude below begin latitude of subdomain  .
pparently not used currently in compuations but subdomain shape uses this
  jend_m2    second latitude above end latitude of subdomain.
 apparently not used currently   but subdomain shape uses this

  ista_m      single longitude before begin longitude
  iend_m      single longitude after  end   longitude
  ista_m2     second longitude before begin longitude
  iend_m2     second longitude after  end   longitude

  ileft.   MPI rank containing the last  longitude before  ista_m
  iright.  MPI rank containing the first longitude after   iend_m
  iup      MPI rank containing the first latitude  after   jend
  idn      MPI rank containing the  last latitude  before  jsta

  ileftb.  MPI rank containing the last longitude before ista_m but for cyclic boundary conditions where "last" at the beginning is the other end of the domain (apparently unused and replaced with local calculation)
  irightb.  MPI rank containing the first longitude after iend_m but for cyclic boundary conditions where "first" at the beginning is the other end of the domain (apparently unused and replaced with local calculation)
