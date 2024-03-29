// Выгрузка растров для визуализации 14 и 15 индикаторов

// Для работы скрипта нужен загруженный в Earth Engine shp с границами городов и поменять ссылку на ассет cities
// Растры выгружаются на Google Drive вашего аккаунта в директорию которая задаётся в строке 63 (    folder: 'index',)
// Экспорт лучше запускать пачками по 100-200 городов (закомментировав остальные строки с id_gis)
// После этого придётся ручками просчёлкать сохранение всех файлов в панеле Tasks в Earth Engine (увы ничего лучше я наколхозить не успел!)


function export_ndvi(idgis) {
  var cities = ee.FeatureCollection('users/felispimeja/cities')
  var aoi = cities.filter(ee.Filter.eq('id_gis', idgis));
  
  function zeroPad(num, places) {
    var zero = places - num.toString().length + 1;
    return Array(+(zero > 0 && zero)).join("0") + num;
  }
  
  var filterCloudSentinel2 = function(img) {
    var quality = img.select('QA60').int();
    var cloudBit = ee.Number(1024);
    var cirrusBit = ee.Number(2048);    
    var cloudFree = quality.bitwiseAnd(cloudBit).eq(0);
    var cirrusFree = quality.bitwiseAnd(cirrusBit).eq(0);
    var clear = cloudFree.bitwiseAnd(cirrusFree);
    
    return img.updateMask(clear);
  };
  
  function calcNDVI(img){
      return img.expression('(b("B8") - b("B4")) / (b("B8") + b("B4"))').rename('NDVI');
  }
  
  function createMediansNDVI(collection,aoi, year, cloud_treschold, beginMonth, endMonth){
    var imgList = [];
      var begin_date = '01'+zeroPad(beginMonth, 2)+year;
      var end_date = ((new Date(year, endMonth, 0)).getDate()).toString()+zeroPad(endMonth, 2)+year;
      var begin_date_f = year+'-'+zeroPad(beginMonth, 2)+'-01';
      var end_date_f = year+'-'+zeroPad(endMonth, 2)+'-'+((new Date(year, endMonth, 0)).getDate()).toString();
          
      var filterParams = collection
        .filterBounds(aoi)
        .filterDate(begin_date_f, end_date_f)
        .filterMetadata('CLOUDY_PIXEL_PERCENTAGE','less_than', cloud_treschold)
        .map(filterCloudSentinel2)
        .map(calcNDVI);
  
      var median = filterParams.select('NDVI').median();
      var clippedMed = median.clip(aoi).rename('NDVI-med-'+begin_date+'-'+end_date);
      imgList.push(clippedMed);
      Map.addLayer(clippedMed, {min: 0.5, max: 1, palette: ['white', 'green']}, 'NDVI '+ idgis);
      
      return (ee.Image(imgList));
  }
  
  var collection = ee.ImageCollection('COPERNICUS/S2_SR');
  var ndvi = createMediansNDVI(collection,aoi, 2020, 20, 5, 9);
  
  print(ndvi);

  Export.image.toDrive({
    image: ndvi,
    region: aoi,   skipEmptyTiles: true,
    description: 'ndvi_' + idgis,
    scale: 20,
    folder: 'index',
    maxPixels: 1e12,
    fileFormat: 'GeoTIFF',
  });
}

export_ndvi(1);
export_ndvi(2);
export_ndvi(3);
export_ndvi(4);
export_ndvi(5);
export_ndvi(6);
export_ndvi(7);
export_ndvi(8);
export_ndvi(9);
export_ndvi(10);
export_ndvi(11);
export_ndvi(12);
export_ndvi(13);
export_ndvi(14);
export_ndvi(15);
export_ndvi(16);
export_ndvi(17);
export_ndvi(18);
export_ndvi(19);
export_ndvi(20);
export_ndvi(21);
export_ndvi(22);
export_ndvi(23);
export_ndvi(24);
export_ndvi(25);
export_ndvi(26);
export_ndvi(27);
export_ndvi(28);
export_ndvi(29);
export_ndvi(30);
export_ndvi(31);
export_ndvi(32);
export_ndvi(33);
export_ndvi(34);
export_ndvi(35);
export_ndvi(36);
export_ndvi(37);
export_ndvi(38);
export_ndvi(39);
export_ndvi(40);
export_ndvi(41);
export_ndvi(42);
export_ndvi(43);
export_ndvi(44);
export_ndvi(45);
export_ndvi(46);
export_ndvi(47);
export_ndvi(48);
export_ndvi(49);
export_ndvi(50);
export_ndvi(51);
export_ndvi(52);
export_ndvi(53);
export_ndvi(54);
export_ndvi(55);
export_ndvi(56);
export_ndvi(57);
export_ndvi(58);
export_ndvi(59);
export_ndvi(60);
export_ndvi(61);
export_ndvi(62);
export_ndvi(63);
export_ndvi(64);
export_ndvi(65);
export_ndvi(66);
export_ndvi(67);
export_ndvi(68);
export_ndvi(69);
export_ndvi(70);
export_ndvi(71);
export_ndvi(72);
export_ndvi(73);
export_ndvi(74);
export_ndvi(75);
export_ndvi(76);
export_ndvi(77);
export_ndvi(78);
export_ndvi(79);
export_ndvi(80);
export_ndvi(81);
export_ndvi(82);
export_ndvi(83);
export_ndvi(84);
export_ndvi(85);
export_ndvi(86);
export_ndvi(87);
export_ndvi(88);
export_ndvi(89);
export_ndvi(90);
export_ndvi(91);
export_ndvi(92);
export_ndvi(93);
export_ndvi(94);
export_ndvi(95);
export_ndvi(96);
export_ndvi(97);
export_ndvi(98);
export_ndvi(99);
export_ndvi(100);
export_ndvi(101);
export_ndvi(102);
export_ndvi(103);
export_ndvi(104);
export_ndvi(105);
export_ndvi(106);
export_ndvi(107);
export_ndvi(108);
export_ndvi(109);
export_ndvi(110);
export_ndvi(111);
export_ndvi(112);
export_ndvi(113);
export_ndvi(114);
export_ndvi(115);
export_ndvi(116);
export_ndvi(117);
export_ndvi(118);
export_ndvi(119);
export_ndvi(120);
export_ndvi(121);
export_ndvi(122);
export_ndvi(123);
export_ndvi(124);
export_ndvi(125);
export_ndvi(126);
export_ndvi(127);
export_ndvi(128);
export_ndvi(129);
export_ndvi(130);
export_ndvi(131);
export_ndvi(132);
export_ndvi(133);
export_ndvi(134);
export_ndvi(135);
export_ndvi(136);
export_ndvi(137);
export_ndvi(138);
export_ndvi(139);
export_ndvi(140);
export_ndvi(141);
export_ndvi(142);
export_ndvi(143);
export_ndvi(144);
export_ndvi(145);
export_ndvi(146);
export_ndvi(147);
export_ndvi(148);
export_ndvi(149);
export_ndvi(150);
export_ndvi(151);
export_ndvi(152);
export_ndvi(153);
export_ndvi(154);
export_ndvi(155);
export_ndvi(156);
export_ndvi(157);
export_ndvi(158);
export_ndvi(159);
export_ndvi(160);
export_ndvi(161);
export_ndvi(162);
export_ndvi(163);
export_ndvi(164);
export_ndvi(165);
export_ndvi(166);
export_ndvi(167);
export_ndvi(168);
export_ndvi(169);
export_ndvi(170);
export_ndvi(171);
export_ndvi(172);
export_ndvi(173);
export_ndvi(174);
export_ndvi(175);
export_ndvi(176);
export_ndvi(177);
export_ndvi(178);
export_ndvi(179);
export_ndvi(180);
export_ndvi(181);
export_ndvi(182);
export_ndvi(183);
export_ndvi(184);
export_ndvi(185);
export_ndvi(186);
export_ndvi(187);
export_ndvi(188);
export_ndvi(189);
export_ndvi(190);
export_ndvi(191);
export_ndvi(192);
export_ndvi(193);
export_ndvi(194);
export_ndvi(195);
export_ndvi(196);
export_ndvi(197);
export_ndvi(198);
export_ndvi(199);
export_ndvi(200);
export_ndvi(201);
export_ndvi(202);
export_ndvi(203);
export_ndvi(204);
export_ndvi(205);
export_ndvi(206);
export_ndvi(207);
export_ndvi(208);
export_ndvi(209);
export_ndvi(210);
export_ndvi(211);
export_ndvi(212);
export_ndvi(213);
export_ndvi(214);
export_ndvi(215);
export_ndvi(217);
export_ndvi(218);
export_ndvi(219);
export_ndvi(220);
export_ndvi(221);
export_ndvi(222);
export_ndvi(223);
export_ndvi(224);
export_ndvi(225);
export_ndvi(226);
export_ndvi(227);
export_ndvi(228);
export_ndvi(229);
export_ndvi(230);
export_ndvi(231);
export_ndvi(232);
export_ndvi(233);
export_ndvi(234);
export_ndvi(235);
export_ndvi(236);
export_ndvi(237);
export_ndvi(238);
export_ndvi(239);
export_ndvi(240);
export_ndvi(241);
export_ndvi(242);
export_ndvi(243);
export_ndvi(244);
export_ndvi(245);
export_ndvi(246);
export_ndvi(247);
export_ndvi(248);
export_ndvi(249);
export_ndvi(250);
export_ndvi(251);
export_ndvi(252);
export_ndvi(253);
export_ndvi(254);
export_ndvi(255);
export_ndvi(256);
export_ndvi(257);
export_ndvi(258);
export_ndvi(259);
export_ndvi(260);
export_ndvi(261);
export_ndvi(262);
export_ndvi(263);
export_ndvi(264);
export_ndvi(265);
export_ndvi(266);
export_ndvi(267);
export_ndvi(268);
export_ndvi(269);
export_ndvi(270);
export_ndvi(271);
export_ndvi(272);
export_ndvi(273);
export_ndvi(274);
export_ndvi(275);
export_ndvi(277);
export_ndvi(278);
export_ndvi(279);
export_ndvi(280);
export_ndvi(281);
export_ndvi(282);
export_ndvi(283);
export_ndvi(284);
export_ndvi(285);
export_ndvi(286);
export_ndvi(287);
export_ndvi(288);
export_ndvi(289);
export_ndvi(290);
export_ndvi(291);
export_ndvi(292);
export_ndvi(293);
export_ndvi(294);
export_ndvi(295);
export_ndvi(296);
export_ndvi(297);
export_ndvi(298);
export_ndvi(299);
export_ndvi(300);
export_ndvi(301);
export_ndvi(302);
export_ndvi(303);
export_ndvi(304);
export_ndvi(305);
export_ndvi(306);
export_ndvi(307);
export_ndvi(308);
export_ndvi(309);
export_ndvi(310);
export_ndvi(311);
export_ndvi(312);
export_ndvi(313);
export_ndvi(314);
export_ndvi(315);
export_ndvi(316);
export_ndvi(317);
export_ndvi(318);
export_ndvi(319);
export_ndvi(320);
export_ndvi(321);
export_ndvi(322);
export_ndvi(323);
export_ndvi(324);
export_ndvi(325);
export_ndvi(326);
export_ndvi(327);
export_ndvi(328);
export_ndvi(329);
export_ndvi(330);
export_ndvi(331);
export_ndvi(332);
export_ndvi(333);
export_ndvi(334);
export_ndvi(335);
export_ndvi(336);
export_ndvi(337);
export_ndvi(338);
export_ndvi(339);
export_ndvi(340);
export_ndvi(341);
export_ndvi(342);
export_ndvi(343);
export_ndvi(344);
export_ndvi(345);
export_ndvi(346);
export_ndvi(347);
export_ndvi(348);
export_ndvi(349);
export_ndvi(350);
export_ndvi(351);
export_ndvi(352);
export_ndvi(353);
export_ndvi(354);
export_ndvi(355);
export_ndvi(356);
export_ndvi(357);
export_ndvi(358);
export_ndvi(359);
export_ndvi(360);
export_ndvi(361);
export_ndvi(362);
export_ndvi(363);
export_ndvi(364);
export_ndvi(365);
export_ndvi(366);
export_ndvi(367);
export_ndvi(368);
export_ndvi(369);
export_ndvi(370);
export_ndvi(371);
export_ndvi(372);
export_ndvi(373);
export_ndvi(374);
export_ndvi(375);
export_ndvi(376);
export_ndvi(377);
export_ndvi(378);
export_ndvi(379);
export_ndvi(380);
export_ndvi(381);
export_ndvi(382);
export_ndvi(383);
export_ndvi(384);
export_ndvi(385);
export_ndvi(386);
export_ndvi(387);
export_ndvi(388);
export_ndvi(389);
export_ndvi(390);
export_ndvi(391);
export_ndvi(392);
export_ndvi(393);
export_ndvi(394);
export_ndvi(395);
export_ndvi(396);
export_ndvi(397);
export_ndvi(398);
export_ndvi(399);
export_ndvi(400);
export_ndvi(401);
export_ndvi(402);
export_ndvi(403);
export_ndvi(404);
export_ndvi(405);
export_ndvi(406);
export_ndvi(407);
export_ndvi(408);
export_ndvi(409);
export_ndvi(410);
export_ndvi(411);
export_ndvi(412);
export_ndvi(413);
export_ndvi(414);
export_ndvi(415);
export_ndvi(416);
export_ndvi(417);
export_ndvi(418);
export_ndvi(419);
export_ndvi(420);
export_ndvi(421);
export_ndvi(422);
export_ndvi(423);
export_ndvi(424);
export_ndvi(425);
export_ndvi(426);
export_ndvi(427);
export_ndvi(428);
export_ndvi(429);
export_ndvi(430);
export_ndvi(431);
export_ndvi(432);
export_ndvi(433);
export_ndvi(434);
export_ndvi(435);
export_ndvi(436);
export_ndvi(437);
export_ndvi(438);
export_ndvi(439);
export_ndvi(440);
export_ndvi(441);
export_ndvi(442);
export_ndvi(443);
export_ndvi(444);
export_ndvi(445);
export_ndvi(446);
export_ndvi(447);
export_ndvi(448);
export_ndvi(449);
export_ndvi(450);
export_ndvi(451);
export_ndvi(452);
export_ndvi(453);
export_ndvi(454);
export_ndvi(455);
export_ndvi(456);
export_ndvi(457);
export_ndvi(458);
export_ndvi(459);
export_ndvi(460);
export_ndvi(461);
export_ndvi(462);
export_ndvi(463);
export_ndvi(464);
export_ndvi(465);
export_ndvi(466);
export_ndvi(467);
export_ndvi(468);
export_ndvi(469);
export_ndvi(470);
export_ndvi(471);
export_ndvi(472);
export_ndvi(473);
export_ndvi(474);
export_ndvi(475);
export_ndvi(476);
export_ndvi(477);
export_ndvi(478);
export_ndvi(479);
export_ndvi(480);
export_ndvi(481);
export_ndvi(482);
export_ndvi(483);
export_ndvi(484);
export_ndvi(485);
export_ndvi(486);
export_ndvi(487);
export_ndvi(488);
export_ndvi(489);
export_ndvi(490);
export_ndvi(491);
export_ndvi(492);
export_ndvi(493);
export_ndvi(494);
export_ndvi(495);
export_ndvi(496);
export_ndvi(497);
export_ndvi(498);
export_ndvi(499);
export_ndvi(500);
export_ndvi(501);
export_ndvi(502);
export_ndvi(503);
export_ndvi(504);
export_ndvi(505);
export_ndvi(506);
export_ndvi(507);
export_ndvi(508);
export_ndvi(509);
export_ndvi(510);
export_ndvi(511);
export_ndvi(512);
export_ndvi(513);
export_ndvi(514);
export_ndvi(515);
export_ndvi(516);
export_ndvi(517);
export_ndvi(518);
export_ndvi(519);
export_ndvi(520);
export_ndvi(521);
export_ndvi(522);
export_ndvi(523);
export_ndvi(524);
export_ndvi(525);
export_ndvi(526);
export_ndvi(527);
export_ndvi(528);
export_ndvi(529);
export_ndvi(530);
export_ndvi(531);
export_ndvi(532);
export_ndvi(533);
export_ndvi(534);
export_ndvi(535);
export_ndvi(536);
export_ndvi(537);
export_ndvi(538);
export_ndvi(539);
export_ndvi(540);
export_ndvi(541);
export_ndvi(542);
export_ndvi(543);
export_ndvi(544);
export_ndvi(545);
export_ndvi(546);
export_ndvi(547);
export_ndvi(548);
export_ndvi(549);
export_ndvi(550);
export_ndvi(551);
export_ndvi(552);
export_ndvi(553);
export_ndvi(554);
export_ndvi(555);
export_ndvi(556);
export_ndvi(557);
export_ndvi(558);
export_ndvi(559);
export_ndvi(560);
export_ndvi(561);
export_ndvi(562);
export_ndvi(563);
export_ndvi(564);
export_ndvi(565);
export_ndvi(566);
export_ndvi(567);
export_ndvi(568);
export_ndvi(569);
export_ndvi(570);
export_ndvi(571);
export_ndvi(572);
export_ndvi(573);
export_ndvi(574);
export_ndvi(575);
export_ndvi(576);
export_ndvi(577);
export_ndvi(578);
export_ndvi(579);
export_ndvi(580);
export_ndvi(581);
export_ndvi(582);
export_ndvi(583);
export_ndvi(584);
export_ndvi(585);
export_ndvi(586);
export_ndvi(587);
export_ndvi(588);
export_ndvi(589);
export_ndvi(590);
export_ndvi(591);
export_ndvi(592);
export_ndvi(593);
export_ndvi(594);
export_ndvi(595);
export_ndvi(596);
export_ndvi(597);
export_ndvi(598);
export_ndvi(599);
export_ndvi(600);
export_ndvi(601);
export_ndvi(602);
export_ndvi(603);
export_ndvi(604);
export_ndvi(605);
export_ndvi(606);
export_ndvi(607);
export_ndvi(608);
export_ndvi(609);
export_ndvi(610);
export_ndvi(611);
export_ndvi(612);
export_ndvi(613);
export_ndvi(614);
export_ndvi(615);
export_ndvi(616);
export_ndvi(617);
export_ndvi(618);
export_ndvi(619);
export_ndvi(620);
export_ndvi(621);
export_ndvi(622);
export_ndvi(623);
export_ndvi(624);
export_ndvi(625);
export_ndvi(626);
export_ndvi(627);
export_ndvi(628);
export_ndvi(629);
export_ndvi(630);
export_ndvi(631);
export_ndvi(632);
export_ndvi(633);
export_ndvi(634);
export_ndvi(635);
export_ndvi(636);
export_ndvi(637);
export_ndvi(638);
export_ndvi(639);
export_ndvi(640);
export_ndvi(641);
export_ndvi(642);
export_ndvi(643);
export_ndvi(644);
export_ndvi(645);
export_ndvi(646);
export_ndvi(647);
export_ndvi(648);
export_ndvi(649);
export_ndvi(650);
export_ndvi(651);
export_ndvi(652);
export_ndvi(653);
export_ndvi(654);
export_ndvi(655);
export_ndvi(656);
export_ndvi(657);
export_ndvi(658);
export_ndvi(659);
export_ndvi(660);
export_ndvi(661);
export_ndvi(662);
export_ndvi(663);
export_ndvi(664);
export_ndvi(665);
export_ndvi(666);
export_ndvi(667);
export_ndvi(668);
export_ndvi(669);
export_ndvi(670);
export_ndvi(671);
export_ndvi(672);
export_ndvi(673);
export_ndvi(674);
export_ndvi(675);
export_ndvi(676);
export_ndvi(677);
export_ndvi(678);
export_ndvi(679);
export_ndvi(680);
export_ndvi(681);
export_ndvi(682);
export_ndvi(683);
export_ndvi(684);
export_ndvi(685);
export_ndvi(686);
export_ndvi(687);
export_ndvi(688);
export_ndvi(689);
export_ndvi(690);
export_ndvi(691);
export_ndvi(692);
export_ndvi(693);
export_ndvi(694);
export_ndvi(695);
export_ndvi(696);
export_ndvi(697);
export_ndvi(698);
export_ndvi(699);
export_ndvi(700);
export_ndvi(701);
export_ndvi(702);
export_ndvi(703);
export_ndvi(704);
export_ndvi(705);
export_ndvi(706);
export_ndvi(707);
export_ndvi(708);
export_ndvi(709);
export_ndvi(710);
export_ndvi(711);
export_ndvi(712);
export_ndvi(713);
export_ndvi(714);
export_ndvi(715);
export_ndvi(716);
export_ndvi(717);
export_ndvi(718);
export_ndvi(719);
export_ndvi(721);
export_ndvi(722);
export_ndvi(723);
export_ndvi(724);
export_ndvi(725);
export_ndvi(726);
export_ndvi(727);
export_ndvi(728);
export_ndvi(729);
export_ndvi(730);
export_ndvi(731);
export_ndvi(732);
export_ndvi(733);
export_ndvi(734);
export_ndvi(735);
export_ndvi(736);
export_ndvi(737);
export_ndvi(738);
export_ndvi(739);
export_ndvi(740);
export_ndvi(741);
export_ndvi(742);
export_ndvi(743);
export_ndvi(744);
export_ndvi(745);
export_ndvi(746);
export_ndvi(747);
export_ndvi(748);
export_ndvi(749);
export_ndvi(750);
export_ndvi(751);
export_ndvi(752);
export_ndvi(753);
export_ndvi(754);
export_ndvi(755);
export_ndvi(756);
export_ndvi(757);
export_ndvi(758);
export_ndvi(759);
export_ndvi(760);
export_ndvi(761);
export_ndvi(762);
export_ndvi(763);
export_ndvi(764);
export_ndvi(765);
export_ndvi(766);
export_ndvi(767);
export_ndvi(768);
export_ndvi(769);
export_ndvi(770);
export_ndvi(771);
export_ndvi(772);
export_ndvi(773);
export_ndvi(774);
export_ndvi(775);
export_ndvi(776);
export_ndvi(777);
export_ndvi(778);
export_ndvi(779);
export_ndvi(780);
export_ndvi(781);
export_ndvi(782);
export_ndvi(783);
export_ndvi(784);
export_ndvi(785);
export_ndvi(786);
export_ndvi(787);
export_ndvi(788);
export_ndvi(789);
export_ndvi(790);
export_ndvi(791);
export_ndvi(792);
export_ndvi(793);
export_ndvi(794);
export_ndvi(795);
export_ndvi(796);
export_ndvi(797);
export_ndvi(798);
export_ndvi(799);
export_ndvi(800);
export_ndvi(801);
export_ndvi(802);
export_ndvi(803);
export_ndvi(804);
export_ndvi(805);
export_ndvi(806);
export_ndvi(807);
export_ndvi(808);
export_ndvi(809);
export_ndvi(810);
export_ndvi(811);
export_ndvi(812);
export_ndvi(813);
export_ndvi(814);
export_ndvi(815);
export_ndvi(816);
export_ndvi(817);
export_ndvi(818);
export_ndvi(819);
export_ndvi(820);
export_ndvi(821);
export_ndvi(822);
export_ndvi(823);
export_ndvi(824);
export_ndvi(825);
export_ndvi(826);
export_ndvi(827);
export_ndvi(828);
export_ndvi(829);
export_ndvi(830);
export_ndvi(831);
export_ndvi(832);
export_ndvi(833);
export_ndvi(834);
export_ndvi(835);
export_ndvi(836);
export_ndvi(837);
export_ndvi(838);
export_ndvi(839);
export_ndvi(840);
export_ndvi(841);
export_ndvi(842);
export_ndvi(843);
export_ndvi(844);
export_ndvi(845);
export_ndvi(846);
export_ndvi(847);
export_ndvi(848);
export_ndvi(849);
export_ndvi(850);
export_ndvi(851);
export_ndvi(852);
export_ndvi(853);
export_ndvi(854);
export_ndvi(855);
export_ndvi(856);
export_ndvi(857);
export_ndvi(858);
export_ndvi(859);
export_ndvi(860);
export_ndvi(861);
export_ndvi(862);
export_ndvi(863);
export_ndvi(864);
export_ndvi(865);
export_ndvi(866);
export_ndvi(867);
export_ndvi(868);
export_ndvi(869);
export_ndvi(870);
export_ndvi(871);
export_ndvi(872);
export_ndvi(873);
export_ndvi(874);
export_ndvi(875);
export_ndvi(876);
export_ndvi(877);
export_ndvi(878);
export_ndvi(879);
export_ndvi(880);
export_ndvi(881);
export_ndvi(882);
export_ndvi(883);
export_ndvi(884);
export_ndvi(885);
export_ndvi(886);
export_ndvi(887);
export_ndvi(888);
export_ndvi(889);
export_ndvi(890);
export_ndvi(891);
export_ndvi(892);
export_ndvi(893);
export_ndvi(894);
export_ndvi(895);
export_ndvi(896);
export_ndvi(897);
export_ndvi(898);
export_ndvi(899);
export_ndvi(900);
export_ndvi(901);
export_ndvi(902);
export_ndvi(903);
export_ndvi(904);
export_ndvi(905);
export_ndvi(906);
export_ndvi(907);
export_ndvi(908);
export_ndvi(909);
export_ndvi(910);
export_ndvi(911);
export_ndvi(912);
export_ndvi(913);
export_ndvi(914);
export_ndvi(915);
export_ndvi(916);
export_ndvi(917);
export_ndvi(918);
export_ndvi(919);
export_ndvi(920);
export_ndvi(921);
export_ndvi(922);
export_ndvi(923);
export_ndvi(924);
export_ndvi(925);
export_ndvi(926);
export_ndvi(927);
export_ndvi(928);
export_ndvi(929);
export_ndvi(930);
export_ndvi(931);
export_ndvi(932);
export_ndvi(933);
export_ndvi(934);
export_ndvi(935);
export_ndvi(936);
export_ndvi(937);
export_ndvi(938);
export_ndvi(939);
export_ndvi(940);
export_ndvi(941);
export_ndvi(942);
export_ndvi(943);
export_ndvi(944);
export_ndvi(945);
export_ndvi(946);
export_ndvi(947);
export_ndvi(948);
export_ndvi(949);
export_ndvi(950);
export_ndvi(951);
export_ndvi(952);
export_ndvi(953);
export_ndvi(954);
export_ndvi(955);
export_ndvi(956);
export_ndvi(957);
export_ndvi(958);
export_ndvi(959);
export_ndvi(960);
export_ndvi(961);
export_ndvi(962);
export_ndvi(963);
export_ndvi(964);
export_ndvi(965);
export_ndvi(966);
export_ndvi(967);
export_ndvi(968);
export_ndvi(969);
export_ndvi(970);
export_ndvi(971);
export_ndvi(972);
export_ndvi(973);
export_ndvi(974);
export_ndvi(975);
export_ndvi(976);
export_ndvi(977);
export_ndvi(978);
export_ndvi(979);
export_ndvi(980);
export_ndvi(981);
export_ndvi(982);
export_ndvi(983);
export_ndvi(984);
export_ndvi(985);
export_ndvi(986);
export_ndvi(987);
export_ndvi(988);
export_ndvi(989);
export_ndvi(990);
export_ndvi(991);
export_ndvi(992);
export_ndvi(993);
export_ndvi(994);
export_ndvi(995);
export_ndvi(996);
export_ndvi(997);
export_ndvi(998);
export_ndvi(999);
export_ndvi(1000);
export_ndvi(1001);
export_ndvi(1002);
export_ndvi(1003);
export_ndvi(1004);
export_ndvi(1005);
export_ndvi(1006);
export_ndvi(1007);
export_ndvi(1008);
export_ndvi(1009);
export_ndvi(1010);
export_ndvi(1011);
export_ndvi(1012);
export_ndvi(1013);
export_ndvi(1014);
export_ndvi(1015);
export_ndvi(1016);
export_ndvi(1017);
export_ndvi(1018);
export_ndvi(1019);
export_ndvi(1020);
export_ndvi(1021);
export_ndvi(1022);
export_ndvi(1023);
export_ndvi(1024);
export_ndvi(1025);
export_ndvi(1026);
export_ndvi(1027);
export_ndvi(1028);
export_ndvi(1029);
export_ndvi(1030);
export_ndvi(1031);
export_ndvi(1032);
export_ndvi(1033);
export_ndvi(1034);
export_ndvi(1035);
export_ndvi(1036);
export_ndvi(1037);
export_ndvi(1038);
export_ndvi(1039);
export_ndvi(1040);
export_ndvi(1041);
export_ndvi(1042);
export_ndvi(1043);
export_ndvi(1044);
export_ndvi(1045);
export_ndvi(1046);
export_ndvi(1047);
export_ndvi(1048);
export_ndvi(1049);
export_ndvi(1050);
export_ndvi(1051);
export_ndvi(1052);
export_ndvi(1053);
export_ndvi(1054);
export_ndvi(1055);
export_ndvi(1056);
export_ndvi(1057);
export_ndvi(1058);
export_ndvi(1059);
export_ndvi(1060);
export_ndvi(1061);
export_ndvi(1062);
export_ndvi(1063);
export_ndvi(1064);
export_ndvi(1065);
export_ndvi(1066);
export_ndvi(1067);
export_ndvi(1068);
export_ndvi(1069);
export_ndvi(1070);
export_ndvi(1071);
export_ndvi(1072);
export_ndvi(1073);
export_ndvi(1074);
export_ndvi(1075);
export_ndvi(1076);
export_ndvi(1077);
export_ndvi(1078);
export_ndvi(1079);
export_ndvi(1080);
export_ndvi(1081);
export_ndvi(1082);
export_ndvi(1083);
export_ndvi(1084);
export_ndvi(1085);
export_ndvi(1086);
export_ndvi(1087);
export_ndvi(1088);
export_ndvi(1090);
export_ndvi(1091);
export_ndvi(1092);
export_ndvi(1093);
export_ndvi(1094);
export_ndvi(1095);
export_ndvi(1096);
export_ndvi(1097);
export_ndvi(1098);
export_ndvi(1099);
export_ndvi(1100);
export_ndvi(1101);
export_ndvi(1102);
export_ndvi(1103);
export_ndvi(1104);
export_ndvi(1105);
export_ndvi(1106);
export_ndvi(1107);
export_ndvi(1108);
export_ndvi(1109);
export_ndvi(1110);
export_ndvi(1111);
export_ndvi(1112);
export_ndvi(1113);
export_ndvi(1114);
export_ndvi(1115);
export_ndvi(1117);
export_ndvi(1118);
export_ndvi(1119);
export_ndvi(1120);
export_ndvi(1121);
export_ndvi(1122);
export_ndvi(1123);
