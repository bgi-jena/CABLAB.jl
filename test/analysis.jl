using CABLAB
using Base.Test


function doTests()
  # Test simple Stats first
  c=RemoteCube()

  d = getCubeData(c,variable="air_temperature_2m",longitude=(30,31),latitude=(50,51),
                time=(DateTime("2002-01-01"),DateTime("2008-12-31")))

  dmem=readCubeData(d)

  # Basic statistics
  m=reduceCube(mean,d,TimeAxis,skipnull=true)

  @test isapprox(readCubeData(m).data,[281.922  282.038  282.168  282.288;
                281.936  282.062  282.202  282.331;
                281.949  282.086  282.236  282.375;
                281.963  282.109  282.271  282.418])

  #Test Spatial meann along laitutde axis
  d1=getCubeData(c,variable="gross_primary_productivity",time=(DateTime("2002-01-01"),DateTime("2002-01-01")),longitude=(30,30))

  dmem=readCubeData(d1)
  mtime=reduceCube(mean,dmem,(LonAxis,LatAxis),skipnull=true)

  wv=cosd(dmem.axes[2].values)
  goodinds=dmem.mask.==0x00
  @test Float32(sum(dmem.data[goodinds].*wv[goodinds])/sum(wv[goodinds]))==readCubeData(mtime).data[1]

  # Test Mean seasonal cycle retrieval

  cdata=getCubeData(c,variable="soil_moisture",longitude=(30,30),latitude=(50.75,50.75))
  d=readCubeData(cdata)
  x2=mapCube(getMSC,d)
  x3=mapCube(getMedSC,d)
  dstep3=d.data[1,1,3:46:506]
  mstep3=d.mask[1,1,3:46:506]
  @test mean(dstep3[mstep3.==0x00])==readCubeData(x2).data[3]
  @test median(dstep3[mstep3.==0x00])==readCubeData(x3).data[3]

  # Test gap filling
  cube_filled=readCubeData(mapCube(gapFillMSC,d))
  imiss=findfirst(d.mask)
  @test cube_filled.mask[imiss]==CABLAB.FILLED
  its=div(imiss-1,46)+1
  @test cube_filled.data[imiss]==readCubeData(x2).data[its]
  @test !any(cube_filled.mask.==CABLAB.MISSING)

  # Test removal of MSC

  cube_anomalies=readCubeData(mapCube(removeMSC,cube_filled))
  isapprox(cube_anomalies.data[47:92],(cube_filled.data[47:92].-readCubeData(x2).data[1:46]))

  # Test normalization

  anom_normalized=readCubeData(mapCube(normalizeTS,cube_anomalies))
  @test mean(anom_normalized.data)<1e7
  @test 1.0-1e-6 <= std(anom_normalized.data) <= 1.0+1e-6
  #test anomaly detection



# Test generation of new axes

  @everywhere function catCubes(xout,xin1,xin2)
    Ntime,nvar1=size(xin1)
    nvar2=size(xin2,2)
    for ivar=1:nvar1
      for itime=1:Ntime
        xout[itime,ivar]=xin1[itime,ivar]
      end
    end
    for ivar=1:nvar2
      for itime=1:Ntime
        xout[itime,nvar1+ivar]=xin2[itime,ivar]
      end
    end
  end

  registerDATFunction(catCubes,((TimeAxis,VariableAxis),(TimeAxis,VariableAxis)),(TimeAxis,CategoricalAxis("Variable2",[1,2,3,4])),inmissing=(NaN,NaN),outmissing=:nan)
  d1=getCubeData(c,variable=["gross_primary_productivity","net_ecosystem_exchange"],longitude=(30,30),latitude=(50,50))
  d2=getCubeData(c,variable=["gross_primary_productivity","air_temperature_2m"],longitude=(30,30),latitude=(50,50))

  ccube=mapCube(catCubes,(d1,d2))

  nothing
end

doTests()

addprocs(2)
CABLAB.DAT.init_DATworkers()

doTests()
rmprocs(workers())
