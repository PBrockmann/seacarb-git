# Copyright (C) 2008 Jean-Pierre Gattuso and Heloise Lavigne and Aurelien Proye # with a most valuable contribution of Bernard Gentili <gentili@obs-vlfr.fr> 
# and valuable suggestions from Jean-Marie Epitalon <epitalon@lsce.saclay.cea.fr> 
# # This file is part of seacarb. 
# # Seacarb is free software; you can redistribute it and/or modify it under the terms of the GNU General Public License as published by the Free Software Foundation; either version 2 of the License, or any later version. 
# # Seacarb is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for more details. 
# # You should have received a copy of the GNU General Public License along with seacarb; if not, write to the Free Software Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA # #  

# New version of buffesm accounts for effects of nutrient (Si and P) concentrations
# ---------------------------------------------------------------------------------

buffesm <-  
  function(flag, var1, var2, S=35, T=25, Patm=1, P=0, Pt=0, Sit=0, k1k2='x', kf='x', ks="d", pHscale="T", b="u74", warn="y",  eos="eos80", long=1.e20, lat=1.e20){
    n <- max(length(flag), length(var1), length(var2), length(S), length(T), length(P), length(Pt), length(Sit), length(k1k2), length(kf), length(pHscale), length(ks), length(b))
    if(length(flag)!=n){flag <- rep(flag[1],n)}
    if(length(var1)!=n){var1 <- rep(var1[1],n)}
    if(length(var2)!=n){var2 <- rep(var2[1],n)}
    if(length(S)!=n){S <- rep(S[1],n)}
    if(length(T)!=n){T <- rep(T[1],n)}
    if(length(Patm)!=n){Patm <- rep(Patm[1],n)}
    if(length(P)!=n){P <- rep(P[1],n)}
    if(length(Pt)!=n){Pt <- rep(Pt[1],n)}
    if(length(Sit)!=n){Sit <- rep(Sit[1],n)}
    if(length(k1k2)!=n){k1k2 <- rep(k1k2[1],n)}
    if(length(kf)!=n){kf <- rep(kf[1],n)}
    if(length(ks)!=n){ks <- rep(ks[1],n)}
    if(length(pHscale)!=n){pHscale <- rep(pHscale[1],n)}
    if(length(b)!=n){b <- rep(b[1],n)}

    # if the concentrations of total silicate and total phosphate are NA
    # they are set at 0
    Sit[is.na(Sit)] <- 0
    Pt[is.na(Pt)] <- 0

    # Only two options for eos
    if (eos != "teos10" && eos != "eos80")
        stop ("invalid parameter eos: ", eos)
    
    # if use of EOS-10 standard
    if (eos == "teos10")
    {
        # Must convert temperature and salinity from TEOS-10 to EOS-80
        # convert temperature: from Conservative (CT) to in-situ temperature
        # and salinity from Absolute to Practical (SP)
        eos <- teos2eos_geo (S, T, P, long, lat)
        InsT <- eos$T
        SP <- eos$SP
    }
    else
    {
        InsT <- T
        SP <- S
    }

     Carb <- carb(flag=flag, var1=var1, var2=var2, S=SP, T=InsT, Patm=Patm, P=P, Pt=Pt, Sit=Sit, k1k2=k1k2, kf=kf, ks=ks, pHscale=pHscale, b=b)
 	P    <- Carb$P
 	pH   <- Carb$pH
	h    <- 10^(-pH)
	CO2  <- Carb$CO2
	HCO3 <- Carb$HCO3
	CO3  <- Carb$CO3
	DIC  <- Carb$DIC
	ALK  <- Carb$ALK
	Oa   <- Carb$OmegaAragonite
	Oc   <- Carb$OmegaCalcite

    #-------Constants----------------  
    tk = 273.15;           # [K] (for conversion [deg C] <-> [K])
    TK = InsT + tk;           # TK [K]; InsT[C]
    
    Cl = SP / 1.80655;            # Cl = chlorinity; SP = practical salinity (psu)
    ST = 0.14 * Cl/96.062        # (mol/kg) total sulfate  (Dickson et al., 2007, Table 2)
    FLUO = 6.7e-5 * Cl/18.9984   # (mol/kg) total fluoride (Dickson et al., 2007, Table 2)
    bor = bor(S=SP , b=b)         # (mol/kg) total boron

    #---------------------------------------------------------------------
    #--------------------- compute K's ----------------------------------
    #---------------------------------------------------------------------
    
    # Ks (free pH scale) at zero pressure and given pressure
    Ks_P0 <- Ks(S=SP, T=InsT, P=0, ks=ks, warn=warn)
    Ks    <- Ks(S=SP, T=InsT, P=P, ks=ks, warn=warn)
    
    # Kf on free pH scale
    Kff_P0 <- Kf(S=SP, T=InsT, P=0, pHscale="F", kf=kf, Ks_P0, Ks)
    Kff <- Kf(S=SP, T=InsT, P=P, pHscale="F", kf=kf, Ks_P0, Ks)
    # Kf on given pH scale
    Kf <- Kf(S=SP, T=InsT, P=P, pHscale=pHscale, kf=kf, Ks_P0, Ks)
    
    # Conversion factor from total to SWS pH scale at zero pressure
    ktotal2SWS_P0 <- kconv(S=SP,T=InsT,P=P,kf=kf,Ks=Ks_P0,Kff=Kff_P0)$ktotal2SWS

    # Conversion factor from SWS to chosen pH scale
    conv <- kconv(S=SP,T=InsT,P=P,kf=kf,Ks=Ks,Kff=Kff)
    kSWS2chosen <- rep(1.,n)
    kSWS2chosen [pHscale == "T"] <- conv$kSWS2total [pHscale == "T"]
    kSWS2chosen [pHscale == "F"] <- conv$kSWS2free [pHscale == "F"]  

   # Commented out lines below when specific K is not used in subsequent buffer factor calculations
   #K1 <- K1(S=SP, T=InsT, P=P, pHscale=pHscale, k1k2=k1k2, kSWS2chosen, ktotal2SWS_P0, warn=warn)   
   #K2 <- K2(S=SP, T=InsT, P=P, pHscale=pHscale, k1k2=k1k2, kSWS2chosen, ktotal2SWS_P0, warn=warn)
    Kw <- Kw(S=SP, T=InsT, P=P, pHscale=pHscale, kSWS2chosen, warn=warn)
   #K0 <- K0(S=SP, T=InsT, Patm=Patm, P=P, warn=warn)
    Kb <- Kb(S=SP, T=InsT, P=P, pHscale=pHscale, kSWS2chosen, ktotal2SWS_P0, warn=warn)
   K1p <- K1p(S=SP, T=InsT, P=P, pHscale=pHscale, kSWS2chosen, warn=warn)
   K2p <- K2p(S=SP, T=InsT, P=P, pHscale=pHscale, kSWS2chosen, warn=warn)
   K3p <- K3p(S=SP, T=InsT, P=P, pHscale=pHscale, kSWS2chosen, warn=warn)
   Ksi <- Ksi(S=SP, T=InsT, P=P, pHscale=pHscale, kSWS2chosen, warn=warn)
   #Kspa <- Kspa(S=SP, T=InsT, P=P, warn=warn)
   #Kspc <- Kspc(S=SP, T=InsT, P=P, warn=warn)

   #rho <- rho(S=SP,T=InsT,P=P)

   # Compute potential K0 with S, potential temperature, and atmospheric pressure (usually 1 atm)
   #K0pot <- K0(S=SP, T=theta(S=SP, T=InsT, P=P, Pref=0), Patm=Patm, P=0)

   #--------------------------------------------------------------------- 
   #--------------------    buffer effects    --------------------------- 
   #---------------------------------------------------------------------  
   #   	Buffer Factors from Egleston et al. (2010), Glob. Biogeochem. Cycles, 24, GB1002, doi:10.1029/2008GB003407  
   #       Std definitions needed to comput buffer factors 
   
   Alkc = (2*CO3 + HCO3) 	
   Borate  = (bor / (1 + h/Kb))  
   # could also use equivalent formulation of Borate = bor * Kb / (Kb + h) 	
   oh = Kw / h

   # Phosphorus inorganic species
   # [h2po4-] = K1p * [h3po4] / [H+]
   # [hpo4--] = K1p * K2p * [h3po4] / [H+]²
   # [po4---] = K1p * K2p * K3p * [h3po4] / [H+]³
   # Pt       = [h3po4] * (1 + K1p/[H+] + K1p*K2p/[H+]² + K1p*K2p*K3p/[H+]³)
   h3po4 = Pt / (1 + K1p/h + K1p*K2p/h^2 + K1p*K2p*K3p/h^3)
   h2po4 = K1p * h3po4 / h
   hpo4  = K2p * h2po4 / h
   po4   = K3p * hpo4  / h
   
   # Silicon inorganic species
   # [SiO(OH)3-] = Ksi * [Si(OH)4] / [H+]
   # Sit = [Si(OH)4] * (1 + Ksi / [H+])
   sioh4 = Sit /(1 + Ksi/h)
   # sioh3 = Ksi * sioh4/h
   sioh3 = Ksi * Sit/(h+Ksi)
      
   # Special definitions needed for buffer-factor calculations 
   #  - originally from Table 1 of Egleston et al;  
   #  - later modified to comply w/ formulas in Excel sheet of Chris Sabine (23 Aug 2010) 	
   # ------------------------------------------------------------------------------------
   # BAD formula in Table 1 (Egleston et al., 2010) - last sign is inversed
   # Segle   = (HCO3 + 4*CO3 + (h*Borate/(Kb + h)) + h - oh)  
   # GOOD formula with last sign above inverted (1st line of code just below),
   # ...  also added are effects from phosphoric and silicic acid systems (code lines 2-6 just below)
   #      The addition of these 2 acid systems from J.-M. Epitalon, 2016 (expanded equation from Egleston)
   SegleC = ( HCO3 + 4*CO3 + (h*Borate/(Kb + h)) + h + oh)

   numPt <-  - h3po4 * (-h2po4 - 2*hpo4 - 3*po4)
             + hpo4  * (2*h3po4 + h2po4 - po4)
             + 2*po4 * (3*h3po4 + 2*h2po4 + hpo4)
   # Protect against division by zero
   SegleP <- rep(0.0,n)
   SegleP[Pt > 0] <- numPt[Pt > 0] / Pt[Pt > 0]

   SegleSi =  h * sioh3/(Ksi + h)

   Segle <- SegleC + SegleP + SegleSi

   # GOOD formula from Sabine (Excel sheet, 23 Aug 2010)
   Pegle  = (2*CO2 + HCO3)                                  

   # GOOD formula from Table 1 (Egleston et al.)
   # Qegle  = (HCO3 - (h*Borate/(Kb + h)) - h - oh)           
   # GOOD formula from Sabine (Excel sheet, 23 Aug 2010)
   Qegle  = 2*Alkc - Segle                                 
   #Formula derived by J. Orr (same result as line just above)

   # #Compute 6 buffer factors: 
   #  *** NOTE - units of buffer factors (mol/kg) 
   #           - to convert to mmol/kg (units shown by Egleston), multiply each factor by 1000 after calling this routine 
   	
   gammaDIC = (DIC - (Alkc*Alkc)/Segle) 	
   gammaALK = ( (Alkc*Alkc - DIC*Segle) / Alkc ) 	
   betaDIC  = ( (DIC*Segle - Alkc*Alkc) / Alkc ) 	
   betaALK  = (Alkc*Alkc/DIC - Segle) 	

   # BAD Formula from Table 1 (Egleston et al.) - replace HCO3 by Qegle 	
   # omegaDIC = ( DIC - (Alkc*Pegle/HCO3) )                  
   # GOOD Formula from Sabine (Excel sheet, 23 Aug 2010) 	
   omegaDIC = ( DIC - (Alkc*Pegle/Qegle) )                  

   # BAD Formula from Table 1 (Egleston et al.) - replace HCO3 by Qegle 	
   # omegaALK = (Alkc - DIC*HCO3/Pegle)                       
   # GOOD Formula from Sabine (Excel sheet, 23 Aug 2010)  
   omegaALK = ( Alkc - DIC*Qegle/Pegle )                    

   # Revelle Factor (agrees exactly with that computed in seacarb's "buffer" function (BetaD, from Frankignoulle, 1994)  
   # when total dissolved inorganic phosphorus & silica concentrations are zero (Orr and Epitalon, 2015; Orr et al., 2015)
   # Now in this new version of 'buffesm', R accounts for these 2 acid systems.
   R = (DIC/gammaDIC)  	

   col <- c("gammaDIC", "betaDIC", "omegaDIC", "gammaALK", "betaALK", "omegaALK", "R") 	
   res <- data.frame(gammaDIC, betaDIC, omegaDIC, gammaALK, betaALK, omegaALK, R) 	
   names(res) <- col 
    
   return(res)
  }
