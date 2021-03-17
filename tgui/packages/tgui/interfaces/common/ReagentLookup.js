import { useBackend } from '../../backend';
import { Box, Button, Icon, LabeledList } from '../../components';

export const ReagentLookup = (props, context) => {
  const { reagent, temp, pressure} = props;
  const { act } = useBackend(context);
  if (!reagent) {
    return (
      <Box>
        No reagent selected!
      </Box>
    );
  }

  return (
    <LabeledList>
      <LabeledList.Item label="Reagent">
        <Icon name="circle" mr={1} color={reagent.reagentCol} />
        {reagent.name}
        <Button
          ml={1}
          icon="wifi"
          color="teal"
          tooltip="Open the associated wikipage for this reagent."
          tooltipPosition="left"
          onClick={() => {
            Byond.command(`wiki Guide_to_chemistry#${reagent.name}`);
          }} />
      </LabeledList.Item>
      <LabeledList.Item label="Description">
        <Box minHeight="50px">
          {reagent.desc}
        </Box>
      </LabeledList.Item>
      <LabeledList.Item label="pH">
        <Icon name="circle" mr={1} color={reagent.pHCol} />
        {reagent.pH}
      </LabeledList.Item>
      <LabeledList.Item label="Properties">
        <LabeledList>
          {!!reagent.OD && (
            <LabeledList.Item label="Overdose">
              {reagent.OD}u
            </LabeledList.Item>
          )}
          {reagent.addictions[0] && (
            <LabeledList.Item label="Addiction">
              {reagent.addictions.map(addiction => (
                <Box key={addiction}>
                  {addiction}
                </Box>
              ))}
            </LabeledList.Item>
          )}
          <LabeledList.Item label="Metabolization rate">
            {reagent.metaRate}u/s
          </LabeledList.Item>
        </LabeledList>
      </LabeledList.Item>
      <LabeledList.Item label="Phase Diagram">
        <svg background-size="20px" width="100" height="150" >
          <defs>
            <pattern id="grid" patternUnits="userSpaceOnUse" width="100" height="50">
              <rect x="0" y="0" width="100" height="1" fill="#000" opacity="1.0" />
              <rect x="0" y="0" width="1" height="50" fill="#000" opacity="1.0" />
            </pattern>
            <clipPath id="cut-off-excess">
              <rect x="0" y="0" width="500" height="250" />
            </clipPath>
          </defs>
          <text transform="scale(0.5 0.5)" x="0" y="250" text-anchor="middle" fill="white" font-size="16">
            <tspan x="250" y="290" font-weight="bold" font-size="1.4em">Temperature (K)</tspan>
            <tspan x="0" y="270">0</tspan>
            <tspan x="100" y="270">200</tspan>
            <tspan x="200" y="270">400</tspan>
            <tspan x="300" y="270">600</tspan>
            <tspan x="400" y="270">800</tspan>
            <tspan x="500" y="270">1000</tspan>
          </text>
          <text transform="scale(0.5 0.5)" x="0" y="0" text-anchor="middle" transform="rotate(90) scale(0.5 0.5)" fill="white" font-size="16" >
            <tspan x="120" y="60" font-weight="bold" font-size="1.4em">Pressure(kPa)</tspan>
          </text>
          <text transform="scale(0.5 0.5)" x="0" y="0" text-anchor="middle" fill="white" font-size="16" >
            <tspan x="-20" y="0" dy="6">500</tspan>
            <tspan x="-20" y="50" dy="6">400</tspan>
            <tspan x="-20" y="100" dy="6">300</tspan>
            <tspan x="-20" y="150" dy="6">200</tspan>
            <tspan x="-20" y="200" dy="6">100</tspan>
            <tspan x="-20" y="250" dy="6">0</tspan>
          </text>
          <g transform="scale(0.5 0.5)">
            <polygon points="0,0 0,250 500,250 500,0" opacity="1" style="fill:#5fcffc" />
            {reagent.phaseProfiles.reverse().map(phase => (
              <>
                <polygon points={`0,250 ${(phase.x1/2)},${250-(phase.y1)} ${(phase.x2/2)},${250-(phase.y2/2)} 500,0 0,0 `} opacity="1" style={`fill:${phase.color}`} clip-path="url(#cut-off-excess)"/>
                <line x1={(phase.x1/2)} y1={250-(phase.y1/2)} x2={(phase.x2/2)} y2={250-(phase.y2/2)} opacity="0.5" stroke={phase.color} stroke-width={phase.range} clip-path="url(#cut-off-excess)"/>
              </>
            ))}
            <circle id="point" cx={temp/2} cy={250-(pressure/2)} r="7" fill="red" />
          </g>
          <rect transform="scale(0.5 0.5)" fill="url(#grid)" stroke-width="2" opacity="0.5" stroke="#000" x="0" y="0" width="500" height="250" />

        </svg>
      </LabeledList.Item>
      <LabeledList.Item label="Impurities">
        <LabeledList>
          {reagent.impureReagent && (
            <LabeledList.Item label="Impure reagent">
              <Button
                icon="vial"
                tooltip="This reagent will partially convert into this when the purity is above the Inverse purity on consumption."
                tooltipPosition="left"
                content={reagent.impureReagent}
                onClick={() => act('reagent_click', {
                  id: reagent.impureId,
                })} />
            </LabeledList.Item>
          )}
          {reagent.inverseReagent && (
            <LabeledList.Item label="Inverse reagent">
              <Button
                icon="vial"
                content={reagent.inverseReagent}
                tooltip="This reagent will convert into this when the purity is below the Inverse purity on consumption."
                tooltipPosition="left"
                onClick={() => act('reagent_click', {
                  id: reagent.inverseId,
                })} />
            </LabeledList.Item>
          )}
          {reagent.failedReagent && (
            <LabeledList.Item label="Failed reagent">
              <Button
                icon="vial"
                tooltip="This reagent will turn into this if the purity of the reaction is below the minimum purity on completion."
                tooltipPosition="left"
                content={reagent.failedReagent}
                onClick={() => act('reagent_click', {
                  id: reagent.failedId,
                })} />
            </LabeledList.Item>
          )}
        </LabeledList>
        {reagent.isImpure && (
          <Box>
            This reagent is created by impurity.
          </Box>
        )}
        {reagent.deadProcess && (
          <Box>
            This reagent works on the dead.
          </Box>
        )}
        {!reagent.failedReagent
          && !reagent.inverseReagent
          && !reagent.impureReagent && (
          <Box>
            This reagent has no impure reagents.
          </Box>
        )}
      </LabeledList.Item>
      <LabeledList.Item>
        <Button
          icon="flask"
          mt={2}
          content={"Find associated reaction"}
          color="purple"
          onClick={() => act('find_reagent_reaction', {
            id: reagent.id,
          })} />
      </LabeledList.Item>
    </LabeledList>
  );
};
