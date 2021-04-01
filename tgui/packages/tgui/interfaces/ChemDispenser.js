import { round, toFixed } from 'common/math';
import { toTitleCase } from 'common/string';
import { useBackend, useLocalState } from '../backend';
import { AnimatedNumber, Tooltip, Box, Button, Icon, Flex, LabeledList, ProgressBar, Section } from '../components';
import { Window } from '../layouts';

export const ChemDispenser = (props, context) => {
  const { act, data } = useBackend(context);
  const recording = !!data.recordingRecipe;
  const { recipeReagents = [] } = data;
  const [hasCol, setHasCol] = useLocalState(
    context, 'has_col', false);
  let offset = 0;
  const incrementOffset = increment => {
    offset += increment;
  };
  // TODO: Change how this piece of shit is built on server side
  // It has to be a list, not a fucking OBJECT!
  const recipes = Object.keys(data.recipes)
    .map(name => ({
      name,
      contents: data.recipes[name],
    }));
  const beakerTransferAmounts = data.beakerTransferAmounts || [];
  const beakerContents = recording
    && Object.keys(data.recordingRecipe)
      .map(id => ({
        id,
        name: toTitleCase(id.replace(/_/, ' ')),
        volume: data.recordingRecipe[id],
      }))
    || data.beakerContents
    || [];
  return (
    <Window
      width={565}
      height={620}>
      <Window.Content scrollable>
        <Section
          title="Status"
          buttons={(
            <>
              {recording && (
                <Box inline mx={1} color="red">
                  <Icon name="circle" mr={1} />
                  Recording
                </Box>
              )}
              <Button
                icon="book"
                disabled={!data.isBeakerLoaded}
                content={"Reaction search"}
                tooltip={data.isBeakerLoaded ? "Look up recipes and reagents!" : "Please insert a beaker!"}
                tooltipPosition="bottom-left"
                onClick={() => act('reaction_lookup')} />
              <Button
                icon="cog"
                tooltip="Color code the reagents by pH"
                tooltipPosition="bottom-left"
                selected={hasCol}
                onClick={() => setHasCol(!hasCol)} />
            </>
          )}>
          <LabeledList>
            <LabeledList.Item label="Energy">
              <ProgressBar
                value={data.energy / data.maxEnergy}>
                {toFixed(data.energy) + ' units'}
              </ProgressBar>
            </LabeledList.Item>
          </LabeledList>
        </Section>
        <Section
          title="Recipes"
          buttons={(
            <>
              {!recording && (
                <Box inline mx={1}>
                  <Button
                    color="transparent"
                    content="Clear recipes"
                    onClick={() => act('clear_recipes')} />
                </Box>
              )}
              {!recording && (
                <Button
                  icon="circle"
                  disabled={!data.isBeakerLoaded}
                  content="Record"
                  onClick={() => act('record_recipe')} />
              )}
              {recording && (
                <Button
                  icon="ban"
                  color="transparent"
                  content="Discard"
                  onClick={() => act('cancel_recording')} />
              )}
              {recording && (
                <Button
                  icon="save"
                  color="green"
                  content="Save"
                  onClick={() => act('save_recording')} />
              )}
            </>
          )}>
          <Box mr={-1}>
            {recipes.map(recipe => (
              <Button
                key={recipe.name}
                icon="tint"
                width="129.5px"
                lineHeight={1.75}
                content={recipe.name}
                onClick={() => act('dispense_recipe', {
                  recipe: recipe.name,
                })} />
            ))}
            {recipes.length === 0 && (
              <Box color="light-gray">
                No recipes.
              </Box>
            )}
          </Box>
        </Section>
        <Section
          title="Dispense"
          buttons={(
            beakerTransferAmounts.map(amount => (
              <Button
                key={amount}
                icon="plus"
                selected={amount === data.amount}
                content={amount}
                onClick={() => act('amount', {
                  target: amount,
                })} />
            ))
          )}>
          <Box mr={-1}>
            {data.chemicals.map(chemical => (
              <Button
                key={chemical.id}
                icon="tint"
                width="129.5px"
                lineHeight={1.75}
                content={chemical.title}
                tooltip={"pH: " + chemical.pH}
                backgroundColor={recipeReagents.includes(chemical.id)
                  ? hasCol ? "black" : "green"
                  : hasCol ? chemical.pHCol : "default"}
                onClick={() => act('dispense', {
                  reagent: chemical.id,
                })} />
            ))}
          </Box>
        </Section>
        <Section
          title="Beaker"
          buttons={(
            beakerTransferAmounts.map(amount => (
              <Button
                key={amount}
                icon="minus"
                disabled={recording}
                content={amount}
                onClick={() => act('remove', { amount })} />
            ))
          )}>
          <LabeledList>
            <LabeledList.Item
              label="Beaker"
              buttons={!!data.isBeakerLoaded && (
                <>
                <Button
                  icon="eject"
                  content="Eject"
                  disabled={!data.isBeakerLoaded}
                  onClick={() => act('eject')} />
                <Button
                  icon={!data.isBeakerSealed ? "compress-arrows-alt" : "compress"}
                  content={data.isBeakerSealed ? "Unseal" : "Seal"}
                  disabled={!data.isBeakerLoaded}
                  onClick={() => act('seal')} />
                </>
              )}>
              {recording
                && 'Virtual beaker'
                || data.isBeakerLoaded
                  && (
                    <>
                      <AnimatedNumber
                        initial={0}
                        value={data.beakerCurrentVolume} />
                      /{data.beakerMaxVolume} units
                    </>
                  )
                || 'No beaker'}
            </LabeledList.Item>
            <LabeledList.Item
              label="Contents">
              <Box color="label">
                {(!data.isBeakerLoaded && !recording) && 'N/A'
                  || beakerContents.length === 0 && 'Nothing'}
              </Box>
              {beakerContents.map(chemical => (
                <Flex>
                  <Box
                    key={chemical.name}
                    color="label">
                    <AnimatedNumber
                      initial={0}
                      value={chemical.volume} />
                    {' '}
                    units of {chemical.name}
                  </Box>
                    <Flex.Item
                      style={{
                        'justify-content': 'flex-end',
                      }}>
                    <Box
                      ml={1}
                      style={{
                        'position': 'relative',
                        'width': '105px',
                        'height': '16px',
                        'display': 'flex',
                        'justify-content': 'flex-end',
                        'background-color': '#363636',
                        'border': '2px solid #363636',
                        'border-index': '0',
                        'box-shadow': '4px 4px #000000',
                      }}>
                      {chemical.pressureProfile.map(phase => (
                        !!phase.ratio && (
                          <Box
                            key={chemical.name+phase.name}
                            position="relative"
                            color="#000000"
                            style={{
                              'position': 'absolute',
                              'left': `${offset}px`,
                              'width': `${(phase.ratio*100)}%`,
                              'height': '12px',
                              'background-color': `${(phase.color)}`,
                              'transition': '1.2s ease-out',
                            }}>
                            <Tooltip
                              content={`${(phase.name)}: ${round(phase.ratio*100)}%`} />
                            {incrementOffset(phase.ratio*100)}
                          </Box>
                        )
                      ))}
                      {incrementOffset(-100)}
                    </Box>
                  </Flex.Item>
                </Flex>
              ))}
              {((beakerContents.length > 0 && !!data.showpH) && (
                <>
                  <Box>
                    pH:
                    <AnimatedNumber
                      value={data.beakerCurrentpH} />
                  </Box>
                  <Box>
                    Pressure:
                    <AnimatedNumber
                      value={data.pressure+" kPa"} />
                  </Box>
                </>)
              )}
            </LabeledList.Item>
          </LabeledList>
        </Section>
      </Window.Content>
    </Window>
  );
};
