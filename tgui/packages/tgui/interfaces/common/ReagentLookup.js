import { Box, LabeledList, Button, Icon } from '../../components';
import { useBackend } from '../../backend';

export const ReagentLookup = (props, context) => {
  const { reagent } = props;
  const { act } = useBackend(context);
  return (

    reagent && (
      <LabeledList>
        <LabeledList.Item label="Reagent">
          <Icon name="circle" mr={1} color={reagent.reagentCol} />
          {reagent.name}
          <Button
            ml={1}
            content={reagent.name}
            icon="wifi"
            color="teal"
            tooltip="Open the associated wikipage for this reagent."
            tooltipPosition="left"
            onClick={() => 
              Byond.command(`wiki Guide_to_chemistry#${reagent.name}`)} />
        </LabeledList.Item>
        <LabeledList.Item label="Description">
          {reagent.desc}
        </LabeledList.Item>
        <LabeledList.Item label="pH">
          <Icon name="circle" mr={1} color={reagent.pHCol} />
          {reagent.pH}
        </LabeledList.Item>
        <LabeledList.Item label="Properties">
          <LabeledList>
            <LabeledList.Item label="Overdose">
              {reagent.OD}u
            </LabeledList.Item>
            <LabeledList.Item label="Addiction">
              {reagent.Addiction}u
            </LabeledList.Item>
            <LabeledList.Item label="Metabolization rate">
              {reagent.metaRate}u/s
            </LabeledList.Item>
          </LabeledList>
        </LabeledList.Item>
        <LabeledList.Item label="Impurities">
          <LabeledList>
            {reagent.impureReagent && (
              <LabeledList.Item label="Impure reagent">
                <Button
                  key={reagent.impureReagent}
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
                  key={reagent.inverseReagent}
                  icon="vial"
                  content={reagent
                    .inverseReagent}
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
                  key={reagent.failedReagent}
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
            key={reagent.id}
            icon="flask"
            mt={2}
            content={"Find associated reaction"}
            color="purple"
            onClick={() => act('find_reagent_reaction', {
              id: reagent.id,
            })} />
        </LabeledList.Item>
      </LabeledList>
    ) || (
      <Box>
        No reagent selected!
      </Box>
    )
  );
};